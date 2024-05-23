#!/usr/bin/env python3
import argparse
import random
import gzip

class Subsampler:
    def __init__(self, forward_read, reverse_read, forward_out, reverse_out, total_read, target_x, block_size=500*1024*1024):
        self.forward_read_path = forward_read
        self.reverse_read_path = reverse_read
        self.forward_out_path = forward_out
        self.reverse_out_path = reverse_out
        self.total_read = total_read
        self.target_x = target_x
        self.block_size = block_size
        self.genome_size = 3000000000  # Human genome size
        self.read_length = 150  # Typical read length for Illumina sequencing

    def calc_threshold(self):
        total_bp_needed = self.target_x * self.genome_size
        current_coverage = self.total_read * self.read_length
        assert current_coverage != 0, "The number of total read is 0"
        return total_bp_needed / current_coverage
    
    def sequence_generator(self, file_obj):
        block = ""
        while True:
            new_block = file_obj.read(self.block_size)
            if not new_block and not block:
                break

            block += new_block
            lines = block.split('\n')
            pos = block.rfind('\n')
            nlines = len(lines)

            if pos != nlines - 1:
                remainder = file_obj.readline()
                last_incomplete_line = lines.pop(-1) + remainder
                lines.append(last_incomplete_line)

            complete_lines_count = nlines - (nlines % 4)
            yield '\n'.join(lines)
            block = '\n'.join(lines[complete_lines_count:])

    def subsample_sequences(self):
        with gzip.open(self.forward_read_path, 'rt') as forward_read, \
            gzip.open(self.reverse_read_path, 'rt') as reverse_read, \
            gzip.open(self.forward_out_path, 'wb') as forward_out, \
            gzip.open(self.reverse_out_path, 'wb') as reverse_out:
            forward_gen = self.sequence_generator(forward_read)
            reverse_gen = self.sequence_generator(reverse_read)
            
            while True:
                try:
                    forward_block = next(forward_gen)
                    reverse_block = next(reverse_gen)
                    if random.random() < self.calc_threshold():
                        forward_out.write((forward_block + '\n').encode())
                        reverse_out.write((reverse_block + '\n').encode())
                except StopIteration:
                    break

def main():
    parser = argparse.ArgumentParser(description='Subsample FASTQ files to a target coverage.')
    parser.add_argument('-f','--forward_read', required=True, help='Input path for the forward FASTQ file.')
    parser.add_argument('-r','--reverse_read', required=True, help='Input path for the reverse FASTQ file.')
    parser.add_argument('-s','--forward_out', required=True, help='Output path for the forward subsampled FASTQ file.')
    parser.add_argument('-o','--reverse_out', required=True, help='Output path for the reverse subsampled FASTQ file.')
    parser.add_argument('-t','--total_read', type=int, required=True, help='Total number of reads in the input files.')
    parser.add_argument('-x','--target_x', type=float, default=3, help='Target coverage depth of human genome (default: 3 ).')

    args = parser.parse_args()

    subsampler = Subsampler(
        forward_read=args.forward_read,
        reverse_read=args.reverse_read,
        forward_out=args.forward_out,
        reverse_out=args.reverse_out,
        total_read=args.total_read,
        target_x=args.target_x
    )

    subsampler.subsample_sequences()

if __name__ == "__main__":
    main()
