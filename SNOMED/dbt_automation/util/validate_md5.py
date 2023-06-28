import hashlib

# Provide the path to the zip file
zip_file_path = "SnomedCT_ManagedServiceUS_PRODUCTION_US1000124_20230301T120000Z.zip"

# Expected MD5 hash
expected_md5 = "05a841b9480958e11f8cbe2c72ade951"

# Function to calculate the MD5 hash of a file
def calculate_md5(file_path):
    md5_hash = hashlib.md5()
    with open(file_path, "rb") as file:
        for chunk in iter(lambda: file.read(4096), b""):
            md5_hash.update(chunk)
    return md5_hash.hexdigest()

# Validate the MD5 hash
actual_md5 = calculate_md5(zip_file_path)

if actual_md5 == expected_md5:
    print("MD5 hash is valid.")
else:
    print("MD5 hash is not valid.")
    print("Expected MD5 hash:", expected_md5)
    print("Actual MD5 hash:", actual_md5)
