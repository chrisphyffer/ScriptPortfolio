# Ensures that the required fields are in the data dictionary.
def is_valid_json(data, REQUIRED_FIELDS):
    for req in REQUIRED_FIELDS:
        if not req in data:
            return False
    return True