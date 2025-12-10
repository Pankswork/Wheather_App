import boto3
import sys

buckets = [
    "pythonapp-alb-logs-dev-668227158023",
    "pythonapp-cloudtrail-logs-dev-668227158023"
]

s3 = boto3.resource('s3')

for bucket_name in buckets:
    print(f"Cleaning bucket: {bucket_name}")
    try:
        bucket = s3.Bucket(bucket_name)
        # Delete all object versions (required for versioned buckets)
        bucket.object_versions.delete()
        # Delete the bucket itself
        bucket.delete()
        print(f"Deleted bucket: {bucket_name}")
    except Exception as e:
        print(f"Error deleting {bucket_name}: {e}")
