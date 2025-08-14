def to_uc_vector(hex_string: str) -> list[int]:
    # Convert hex string to a list of unsigned char values with null terminator
    raw_bytes = bytes.fromhex(hex_string)
    return list(raw_bytes) + [0]  # add null terminator like in C++

if __name__ == "__main__":
    input_value = "61726520796f75"  # this is "your nigge" in hex
    uc_vector = to_uc_vector(input_value)

    with open("output.txt", "wb") as f:
        f.write(bytes(uc_vector))

    print(f"Saved {len(uc_vector)} bytes to output.txt")
