#!/usr/bin/env python3

import argparse


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description='This script removes trailing characters from the'
        'end of lines of a file')
    parser.add_argument('--in', '-i', help='Path to the input file',
                        required=True)
    parser.add_argument('--out', '-o', help='Path to the output file',
                        required=True)
    parser.add_argument('--character', '-c', help='Character to remove',
                        default=',')
    args = vars(parser.parse_args())
    char = args['character']
    with open(args['in'], 'r') as in_file:
        with open(args['out'], 'w') as out_file:
            buffer = []
            append = buffer.append
            for line in in_file:
                line = line.strip()
                if line[-1] == char:
                    line = line[:-1]
                append(line)
            out_file.write('\r\f'.join(buffer))
