#!/usr/bin/env python3
import sys
import os
import numpy as np
import math
import scipy.stats as stats
from scipy.stats import poisson

class GenomeCoverageAnalyzer:
    def __init__(self, filename):
        self.filename = filename
        self.depth = {}
    
    def _read_coverage_file(self):
        with open(self.filename) as file:
            for line in file:
                parts = line.strip().split('\t')
                if parts[0] != 'genome':
                    pos_id = int(parts[1])
                    if pos_id != 0 and pos_id <= 1000:
                        self.depth[pos_id] = self.depth.get(pos_id, 0) + int(parts[2])

    def _calculate_coverage_statistics(self):
        total_count = sum(self.depth.values())
        freq_mean = sum(pos * count for pos, count in self.depth.items()) / total_count
        freq_sd = math.sqrt(sum((pos - freq_mean) ** 2 * count for pos, count in self.depth.items()) / total_count)

        sorted_keys = sorted(self.depth.keys())
        count_nums = [self.depth[pos] for pos in sorted_keys]
        count_freq = [self.depth[pos] / total_count for pos in sorted_keys]
        cum_freq = np.cumsum(count_freq)

        mode_index = max(self.depth, key=self.depth.get)
        mode_value = (mode_index - freq_mean) / freq_sd
        q75, q25 = np.percentile(sorted_keys, [75 ,25])
        distance = math.sqrt(sum((poisson.cdf(pos, freq_mean) - cf) ** 2 for pos, cf in zip(sorted_keys, cum_freq)))

        print(f"Mode\t{mode_value}")
        print(f"IQR 75%\t{q75}")
        print(f"IQR 25%\t{q25}")
        print(f"IQR 75%-25%\t{q75 - q25}")
        print(f"Distance\t{distance}")

    def analyze_coverage(self):
        self._read_coverage_file()
        self._calculate_coverage_statistics()

if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(f"Usage: python {sys.argv[0]} sorted.bam.genomecov")
    
    analyzer = GenomeCoverageAnalyzer(sys.argv[1])
    analyzer.analyze_coverage()
