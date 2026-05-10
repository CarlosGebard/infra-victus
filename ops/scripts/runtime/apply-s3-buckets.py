#!/usr/bin/env python3
import argparse
import datetime as dt
import hashlib
import hmac
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request


EMPTY_SHA256 = hashlib.sha256(b"").hexdigest()


def load_json(path):
    with open(path, "r", encoding="utf-8") as fh:
        return json.load(fh)


def credentials_from_seaweed_config(path):
    config = load_json(path)
    identities = config.get("identities", [])
    for identity in identities:
        for credential in identity.get("credentials", []):
            access_key = credential.get("accessKey")
            secret_key = credential.get("secretKey")
            if access_key and secret_key:
                return access_key, secret_key
    raise SystemExit(f"No accessKey/secretKey found in {path}")


def signing_key(secret_key, date_stamp, region, service):
    key = ("AWS4" + secret_key).encode("utf-8")
    date_key = hmac.new(key, date_stamp.encode("utf-8"), hashlib.sha256).digest()
    region_key = hmac.new(date_key, region.encode("utf-8"), hashlib.sha256).digest()
    service_key = hmac.new(region_key, service.encode("utf-8"), hashlib.sha256).digest()
    return hmac.new(service_key, b"aws4_request", hashlib.sha256).digest()


def signed_request(method, endpoint, access_key, secret_key, region, bucket, key=None):
    parsed = urllib.parse.urlparse(endpoint)
    if not parsed.scheme or not parsed.netloc:
        raise SystemExit(f"Invalid endpoint: {endpoint}")

    encoded_bucket = urllib.parse.quote(bucket, safe="")
    path = f"/{encoded_bucket}"
    if key:
        encoded_key = "/".join(urllib.parse.quote(part, safe="") for part in key.split("/"))
        path = f"{path}/{encoded_key}"

    now = dt.datetime.now(dt.timezone.utc)
    amz_date = now.strftime("%Y%m%dT%H%M%SZ")
    date_stamp = now.strftime("%Y%m%d")
    service = "s3"
    scope = f"{date_stamp}/{region}/{service}/aws4_request"

    host = parsed.netloc
    canonical_headers = (
        f"host:{host}\n"
        f"x-amz-content-sha256:{EMPTY_SHA256}\n"
        f"x-amz-date:{amz_date}\n"
    )
    signed_headers = "host;x-amz-content-sha256;x-amz-date"
    canonical_request = "\n".join(
        [
            method,
            path,
            "",
            canonical_headers,
            signed_headers,
            EMPTY_SHA256,
        ]
    )
    string_to_sign = "\n".join(
        [
            "AWS4-HMAC-SHA256",
            amz_date,
            scope,
            hashlib.sha256(canonical_request.encode("utf-8")).hexdigest(),
        ]
    )
    signature = hmac.new(
        signing_key(secret_key, date_stamp, region, service),
        string_to_sign.encode("utf-8"),
        hashlib.sha256,
    ).hexdigest()
    authorization = (
        "AWS4-HMAC-SHA256 "
        f"Credential={access_key}/{scope}, "
        f"SignedHeaders={signed_headers}, "
        f"Signature={signature}"
    )

    url = urllib.parse.urlunparse((parsed.scheme, parsed.netloc, path, "", "", ""))
    request = urllib.request.Request(url, method=method)
    request.add_header("Authorization", authorization)
    request.add_header("X-Amz-Date", amz_date)
    request.add_header("X-Amz-Content-Sha256", EMPTY_SHA256)
    return urllib.request.urlopen(request, timeout=15)


def request_ok(method, endpoint, access_key, secret_key, region, bucket, key=None):
    try:
        with signed_request(method, endpoint, access_key, secret_key, region, bucket, key):
            return True
    except urllib.error.HTTPError as exc:
        if exc.code in (200, 204, 301, 302, 403, 404, 405, 409):
            return exc
        raise


def endpoint_ready(endpoint, access_key, secret_key, region):
    try:
        result = request_ok("HEAD", endpoint, access_key, secret_key, region, "__victus_probe__")
        return result is True or isinstance(result, urllib.error.HTTPError)
    except urllib.error.URLError:
        return False


def wait_for_endpoint(endpoint, access_key, secret_key, region, timeout, interval):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if endpoint_ready(endpoint, access_key, secret_key, region):
            print("[OK] endpoint ready")
            return
        print(f"[WAIT] endpoint not ready, retrying in {interval}s")
        time.sleep(interval)
    raise SystemExit(f"S3 endpoint not ready after {timeout}s: {endpoint}")


def ensure_bucket(endpoint, access_key, secret_key, region, bucket):
    head = request_ok("HEAD", endpoint, access_key, secret_key, region, bucket)
    if head is True:
        print(f"[OK] bucket exists: {bucket}")
        return
    if isinstance(head, urllib.error.HTTPError) and head.code not in (404, 405):
        raise SystemExit(f"Unexpected HEAD status for {bucket}: {head.code}")

    try:
        with signed_request("PUT", endpoint, access_key, secret_key, region, bucket):
            print(f"[CREATE] bucket: {bucket}")
    except urllib.error.HTTPError as exc:
        if exc.code == 409:
            print(f"[OK] bucket already exists: {bucket}")
            return
        raise


def ensure_prefix(endpoint, access_key, secret_key, region, bucket, prefix):
    normalized = prefix.strip("/")
    if not normalized:
        return
    key = f"{normalized}/.keep"

    head = request_ok("HEAD", endpoint, access_key, secret_key, region, bucket, key)
    if head is True:
        print(f"[OK] prefix exists: s3://{bucket}/{normalized}/")
        return
    if isinstance(head, urllib.error.HTTPError) and head.code not in (404, 405):
        raise SystemExit(f"Unexpected HEAD status for {bucket}/{key}: {head.code}")

    try:
        with signed_request("PUT", endpoint, access_key, secret_key, region, bucket, key):
            print(f"[CREATE] prefix: s3://{bucket}/{normalized}/")
    except urllib.error.HTTPError as exc:
        raise SystemExit(f"Failed creating prefix {bucket}/{normalized}/: HTTP {exc.code}") from exc


def validate_contract(contract):
    buckets = contract.get("buckets")
    if not isinstance(buckets, list) or not buckets:
        raise SystemExit("Contract must define non-empty buckets list")
    seen = set()
    for item in buckets:
        name = item.get("name")
        if not name or not isinstance(name, str):
            raise SystemExit("Each bucket must define string name")
        if name in seen:
            raise SystemExit(f"Duplicate bucket: {name}")
        seen.add(name)
        prefixes = item.get("prefixes", [])
        if not isinstance(prefixes, list):
            raise SystemExit(f"Bucket {name} prefixes must be a list")


def main():
    parser = argparse.ArgumentParser(description="Apply declarative SeaweedFS S3 buckets.")
    parser.add_argument(
        "--contract",
        default=os.environ.get("S3_BUCKETS_CONTRACT", "/srv/apps/core/seaweedfs/buckets.json"),
    )
    parser.add_argument(
        "--seaweed-s3-config",
        default=os.environ.get("SEAWEED_S3_CONFIG", "/srv/secrets/runtime/seaweed-s3.json"),
    )
    parser.add_argument("--endpoint", default=os.environ.get("S3_ENDPOINT", "http://seaweedfs:8333"))
    parser.add_argument("--region", default=os.environ.get("AWS_REGION", "us-east-1"))
    parser.add_argument(
        "--wait-timeout",
        type=int,
        default=int(os.environ.get("S3_WAIT_TIMEOUT", "120")),
        help="Seconds to wait for the SeaweedFS S3 endpoint before applying the contract.",
    )
    parser.add_argument(
        "--wait-interval",
        type=int,
        default=int(os.environ.get("S3_WAIT_INTERVAL", "3")),
        help="Seconds between S3 readiness probes.",
    )
    args = parser.parse_args()

    contract = load_json(args.contract)
    validate_contract(contract)
    access_key, secret_key = credentials_from_seaweed_config(args.seaweed_s3_config)

    print(f"[INFO] endpoint: {args.endpoint}")
    print(f"[INFO] contract: {args.contract}")
    wait_for_endpoint(
        args.endpoint,
        access_key,
        secret_key,
        args.region,
        args.wait_timeout,
        args.wait_interval,
    )

    for bucket in contract["buckets"]:
        name = bucket["name"]
        ensure_bucket(args.endpoint, access_key, secret_key, args.region, name)
        for prefix in bucket.get("prefixes", []):
            ensure_prefix(args.endpoint, access_key, secret_key, args.region, name, prefix)

    print("[DONE] S3 bucket contract applied")


if __name__ == "__main__":
    try:
        main()
    except urllib.error.URLError as exc:
        raise SystemExit(f"Connection error: {exc}") from exc
