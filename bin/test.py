import pandas as pd
import sys
# order_info = sys.argv[1]
# sample_info = sys.argv[2]

order_info = '../assets/OrderInfo.txt'
sample_info = '../assets/samplesheet.csv'

order_df = pd.read_table(order_info)
sample_df = pd.read_csv(sample_info)

print(order_df)