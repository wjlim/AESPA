#!/usr/bin/env python
import argparse
import pandas as pd

def parse_arguments():
    parser = argparse.ArgumentParser(description="Process some CSV files.")
    parser.add_argument('-s','--sample_name', type=str, required=True, help='Sample name')
    parser.add_argument('-f','--input_file1', type=str, required=True, help='First input CSV file')
    parser.add_argument('-r','--input_file2', type=str, required=True, help='Second input CSV file')
    parser.add_argument('-o','--output_file', type=str, required=True, help='Output file name')
    parser.add_argument('-t','--output_type', type=str, choices = ['csv', 'sqs'], help='Output file name')
    return parser.parse_args()

def csv2sqs(sr, SampleName=''):
    if SampleName == '':
        SampleName = sr['SampleName']
    string_output = f"{SampleName}\
\t{sr['TotalBases']}\
\t{sr['NumReads']}\
\t{sr['TotalN']/sr['TotalBases']*100:.4f}\
\t{(sr['TotalC']+sr['TotalG'])/sr['TotalBases']*100:.2f}\
\t{sr['Q20Bases']/sr['TotalBases']*100:.2f}\
\t{sr['Q30Bases']/sr['TotalBases']*100:.2f}\n" \
    + f"SampleName : {SampleName}\n" \
    + f"Total A : {sr['TotalA']}\n" \
    + f"Total C : {sr['TotalC']}\n" \
    + f"Total G : {sr['TotalG']}\n" \
    + f"Total T : {sr['TotalT']}\n" \
    + f"Total N : {sr['TotalN']}\n" \
    + f"Q30 Bases : {sr['Q30Bases']}\n" \
    + f"Q20 Bases : {sr['Q20Bases']}\n" \
    + f"Avg.ReadSize : {sr['TotalBases']/sr['NumReads']:.1f}"
    return string_output

def main():
    args = parse_arguments()
    
    forward_df = pd.read_csv(args.input_file1)
    reverse_df = pd.read_csv(args.input_file2)
    merged_df = pd.concat([forward_df, reverse_df], axis=0).sum()
    if args.output_type == 'csv':
        merged_df.to_csv(args.output_file)
    else:
        merged_str = csv2sqs(merged_df, args.sample_name)
        forward_str = csv2sqs(forward_df.iloc[0, :], args.sample_name + '_R1')
        reverse_str = csv2sqs(reverse_df.iloc[0, :], args.sample_name + '_R2')
        
        with open(args.output_file, 'w') as ofile:
            ofile.write(merged_str + '\n')
            ofile.write(forward_str + '\n')
            ofile.write(reverse_str)

if __name__ == "__main__":
    main()
