import os
import datetime
import random
from google.cloud import storage


def main():
    bucket_name = os.environ.get("BUCKET_NAME")
    if not bucket_name:
        raise ValueError("BUCKET_NAME environment variable is not set")

    print(f"Starting nightly job for bucket: {bucket_name}")
    storage_client = storage.Client()
    bucket = storage_client.bucket(bucket_name)

    # 1. Create YYYY-MM-DD.txt with a random sentence
    today = datetime.date.today().isoformat()
    blob_name = f"{today}.txt"
    blob = bucket.blob(blob_name)

    sentences = [
        "The quick brown fox jumps over the lazy dog.",
        "Cloud Run Jobs are great for scheduled tasks.",
        "Automation is the future of operations.",
        "Hello from Google Cloud Platform!",
        "Consistency is key to success.",
    ]
    random_sentence = random.choice(sentences)

    print(f"Creating/Overwriting {blob_name} with content: '{random_sentence}'")
    blob.upload_from_string(random_sentence)
    print("Upload complete.")

    # 2. Delete objects older than 3 days
    print("Checking for old files to delete...")
    cutoff_date = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=3)

    blobs = bucket.list_blobs()
    deleted_count = 0

    for blob in blobs:
        # blob.time_created is datetime with timezone
        if blob.time_created < cutoff_date:
            print(f"Deleting {blob.name} (Created: {blob.time_created})")
            blob.delete()
            deleted_count += 1

    print(f"Cleanup complete. Deleted {deleted_count} files.")


if __name__ == "__main__":
    main()
