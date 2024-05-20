#!/usr/bin/env python
import pysam
import sys

def parse_flag(read):
    is_supplementary = read.is_supplementary
    is_unmapped = read.is_unmapped
    is_duplicate = read.is_duplicate
    return is_supplementary, is_unmapped, is_duplicate

def process_bam_file(filename):
    counts = {
        "total_reads": 0,
        "all_mapped_reads": 0,
        "mapRead_in_duplicates": 0,
        "duplicates": 0,
        "all_supple_reads": 0
    }

    with pysam.AlignmentFile(filename, "rb") as bamfile:
        for read in bamfile:
            is_supplementary, is_unmapped, is_duplicate = parse_flag(read)

            if not is_supplementary:
                counts["total_reads"] += 1
                if not is_unmapped:
                    counts["all_mapped_reads"] += 1
                    if is_duplicate:
                        counts["mapRead_in_duplicates"] += 1
                if is_duplicate:
                    counts["duplicates"] += 1
            else:
                counts["all_supple_reads"] += 1
                
    return counts

def print_results(counts):
    counts["mappable_reads"] = counts["all_mapped_reads"] - counts["mapRead_in_duplicates"]
    output_template = ("all_duplicates\t{duplicates}\n"
                        "mapRead_in_duplicates\t{mapRead_in_duplicates}\n"
                        "all_mappable_reads\t{all_mapped_reads}\n"
                        "supplementary\t{all_supple_reads}\n"
                        "mappable_reads\t{mappable_reads}\n"
                        "total_read\t{total_reads}")
    print(output_template.format(**counts))

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python script.py <bam_file_path>")
        sys.exit(1)
    
    bam_file_path = sys.argv[1]
    counts = process_bam_file(bam_file_path)
    print_results(counts)
