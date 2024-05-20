#!/usr/bin/env python
import multiprocessing
import argparse
import gzip
from collections import Counter

class FASTQStatsCalculator:
    def __init__(self, forward_read, reverse_read, sample_name, output_file, threads, chunk_size, block_size):
        self.forward_read = forward_read
        self.reverse_read = reverse_read
        self.sample_name = sample_name
        self.output_file = output_file
        self.threads = threads
        self.chunk_size = chunk_size
        self.block_size = block_size

    def sequence_generator(self, file_path):
        with gzip.open(file_path, 'rt') as f:
            block = ""
            while True:
                new_block = f.read(self.block_size)
                if not new_block and not block:
                    break
                block += new_block
                lines = block.split('\n')
                pos = block.rfind('\n')
                nlines = len(lines)
                
                if pos != nlines - 1:
                    remainder = f.readline()
                    last_incomplete_line = lines.pop(-1) + remainder
                    lines.append(last_incomplete_line)
                    
                complete_lines_count = nlines - (nlines % 4)
                for i in range(1, complete_lines_count, 2):
                    seq = lines[i].strip()
                    yield seq
                block = '\n'.join(lines[complete_lines_count:])

    def chunked_sequences_generator(self, file_path):
        chunk = []
        for sequence in self.sequence_generator(file_path):
            chunk.append(sequence)
            if len(chunk) == self.chunk_size:
                yield chunk
                chunk = []
        if chunk:
            yield chunk

    @staticmethod
    def process_sequence_chunk(sequences):
        base_counter, num_reads, q20_counter, q30_counter = Counter(), 0, 0, 0
        for i, sequence in enumerate(sequences):
            if i % 2 == 0:
                base_counter.update(sequence)
                num_reads += 1
            else:
                q30_counter += sum(ord(char) - 33 >= 30 for char in sequence)
                q20_counter += sum(ord(char) - 33 >= 20 for char in sequence)
        return base_counter, num_reads, q20_counter, q30_counter

    def process_file(self, file_path, pool):
        total_count, total_num_reads, total_q20_count, total_q30_count = Counter(), 0, 0, 0
        for result in pool.imap_unordered(self.process_sequence_chunk, self.chunked_sequences_generator(file_path)):
            base_counter, num_reads, q20_count, q30_count = result
            total_count.update(base_counter)
            total_num_reads += num_reads
            total_q20_count += q20_count
            total_q30_count += q30_count
        return total_count, total_num_reads, total_q20_count, total_q30_count

    @staticmethod
    def write_stats(output_file, sample_name, stats, write_mode='w'):
        total_bases, total_reads, q20_bases, q30_bases = stats
        total_num = sum(total_bases.values())
        gc_content = (total_bases['G'] + total_bases['C']) * 100 / total_num if total_num > 0 else 0
        n_content = (total_bases['N'] / total_num) if 'N' in total_bases and total_num > 0 else 0
        with open(output_file, write_mode) as out:
            out.write(f"{sample_name}\t{total_num}\t{total_reads}\t{gc_content:.2f}\t{n_content:.4f}\t{q20_bases * 100 / total_num:.2f}\t{q30_bases * 100 / total_num:.2f}\n")
            out.write(f"SampleName : {sample_name}\n")
            for base in 'ACTGN':
                out.write(f"Total {base} : {total_bases[base]}\n")
            out.write(f"Q30 Bases : {q30_bases}\nQ20 Bases : {q20_bases}\n")
            out.write(f"Avg.ReadSize : {total_num/total_reads:.1f}\n")

    def run(self):
        with multiprocessing.Pool(self.threads) as pool:
            forward_stats = self.process_file(self.forward_read, pool)
            if self.reverse_read:
                total_counter = Counter()
                reverse_stats = self.process_file(self.reverse_read, pool)
                total_counter.update(forward_stats[0])
                total_counter.update(reverse_stats[0])
                total_num_reads = forward_stats[1] + reverse_stats[1]
                total_q20_count = forward_stats[2] + reverse_stats[2]
                total_q30_count = forward_stats[3] + reverse_stats[3]
                total_stats = (total_counter, total_num_reads, total_q20_count, total_q30_count)
                self.write_stats(self.output_file, self.sample_name, total_stats, write_mode='a')
                self.write_stats(self.output_file, f"{self.sample_name}_1", forward_stats, write_mode='a')
                self.write_stats(self.output_file, f"{self.sample_name}_2", reverse_stats, write_mode='a')
            else:
                self.write_stats(self.output_file, self.sample_name, forward_stats)

def main():
    parser = argparse.ArgumentParser(description="FASTQ Statistics Calculator with Multiprocessing")
    parser.add_argument("-f", "--forward", required=True, help="Forward read (or single-end read)")
    parser.add_argument("-r", "--reverse", help="Reverse read (for paired-end only)")
    parser.add_argument("-s", "--sample_name", required=True, help="Sample name")
    parser.add_argument("-o", "--output_file", default='output.sqs', help="Output file name")
    parser.add_argument("-t", "--threads", default=8, type=int, help="Number of threads for multiprocessing")
    parser.add_argument("--chunk_size", default=300000, type=int, help="Number of sequences per chunk")
    parser.add_argument("--block_size", default=1024*1024*1024, type=int, help="Block size in bytes for reading the file")

    args = parser.parse_args()
    
    multiprocessing.set_start_method('spawn')
    calculator = FASTQStatsCalculator(
        args.forward,
        args.reverse,
        args.sample_name,
        args.output_file,
        args.threads,
        args.chunk_size,
        args.block_size
    )
    
    calculator.run()

if __name__ == "__main__":
    main()
        