#!/usr/bin/python3

import argparse, os

import argparse

def binary_to_ascii(input_file, output_file):
    try:
        with open(input_file, 'rb') as f_in:
            with open(output_file, 'w') as f_out:
                f_out.write("@0000\n")
                byte = f_in.read(1)
                while byte:
                    hex_repr = "{:02x}\n".format(ord(byte))
                    f_out.write(hex_repr)
                    byte = f_in.read(1)
    except FileNotFoundError:
        print("Error: Input file not found.")
    except Exception as e:
        print(f"An error occurred: {e}")



if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Convert an arbitrary binary file to an ASCII text file.")
    parser.add_argument("input_file", help="Path to the input binary file")
    parser.add_argument("output_file", nargs='?', help="Path to the output ASCII text file (default: input file name with .mem extension)")

    args = parser.parse_args()
    input_file_path = args.input_file
    output_file_path = args.output_file

    if not output_file_path:
        output_file_path = os.path.splitext(input_file_path)[0] + ".mem"

    binary_to_ascii(input_file_path, output_file_path)
    print("Conversion complete.")