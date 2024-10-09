#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <zlib.h>
#include <pthread.h>
#include <ctype.h>

#define BLOCK_SIZE 1024 * 1024  // 1MB buffer size

typedef struct {
    char *forward_read;
    char *reverse_read;
    char *sample_name;
    char *output_file;
    int threads;
} Args;

typedef struct {
    unsigned long long total_bases[256];
    unsigned long long total_reads;
    unsigned long long q20_bases;
    unsigned long long q30_bases;
} Stats;

void update_stats(Stats *stats, const char *seq, const char *qual) {
    for (size_t i = 0; seq[i] != '\0'; ++i) {
        stats->total_bases[(unsigned char)seq[i]]++;
        if ((qual[i] - 33) >= 20) {
            stats->q20_bases++;
        }
        if ((qual[i] - 33) >= 30) {
            stats->q30_bases++;
        }
    }
    stats->total_reads++;
}

void *process_file(void *arg) {
    Args *args = (Args *)arg;
    gzFile file = gzopen(args->forward_read, "r");
    if (!file) {
        perror("gzopen");
        pthread_exit(NULL);
    }

    Stats *stats = (Stats *)calloc(1, sizeof(Stats));
    if (!stats) {
        perror("calloc");
        gzclose(file);
        pthread_exit(NULL);
    }

    char *buffer = (char *)malloc(BLOCK_SIZE);
    char *seq = NULL;
    char *qual = NULL;
    size_t seq_len = 0, qual_len = 0;
    size_t line_len = 0;
    char *line = NULL;

    while ((line_len = gzgets(file, buffer, BLOCK_SIZE)) != -1) {
        // Sequence line
        if (seq_len == 0) {
            seq = strdup(buffer);
            seq_len = line_len;
            continue;
        }

        // Quality line
        if (qual_len == 0) {
            qual = strdup(buffer);
            qual_len = line_len;
            printf("%s", seq);  // Print sequence line
            update_stats(stats, seq, qual);
            free(seq);
            free(qual);
            seq_len = 0;
            qual_len = 0;
            continue;
        }
    }

    free(buffer);
    gzclose(file);
    pthread_exit(stats);
}

void write_stats(const char *output_file, const char *sample_name, Stats *stats) {
    FILE *out = fopen(output_file, "a");
    if (!out) {
        perror("fopen");
        return;
    }

    unsigned long long total_bases = 0;
    for (int i = 0; i < 256; ++i) {
        total_bases += stats->total_bases[i];
    }

    double gc_content = (double)(stats->total_bases['G'] + stats->total_bases['C']) * 100 / total_bases;
    double n_content = stats->total_bases['N'] * 100 / total_bases;
    double q20_percentage = stats->q20_bases * 100 / total_bases;
    double q30_percentage = stats->q30_bases * 100 / total_bases;

    fprintf(out, "%s\t%llu\t%llu\t%.2f\t%.4f\t%.2f\t%.2f\n", sample_name, total_bases, stats->total_reads, gc_content, n_content, q20_percentage, q30_percentage);
    fprintf(out, "SampleName : %s\n", sample_name);
    for (char base = 'A'; base <= 'Z'; ++base) {
        fprintf(out, "Total %c : %llu\n", base, stats->total_bases[(unsigned char)base]);
    }
    fprintf(out, "Q30 Bases : %llu\nQ20 Bases : %llu\n", stats->q30_bases, stats->q20_bases);
    fprintf(out, "Avg.ReadSize : %.1f\n", (double)total_bases / stats->total_reads);

    fclose(out);
}

int main(int argc, char **argv) {
    if (argc < 5) {
        fprintf(stderr, "Usage: %s <forward_read> <reverse_read> <sample_name> <output_file> <threads>\n", argv[0]);
        return EXIT_FAILURE;
    }

    Args args;
    args.forward_read = argv[1];
    args.reverse_read = argv[2];
    args.sample_name = argv[3];
    args.output_file = argv[4];
    args.threads = atoi(argv[5]);

    pthread_t *threads = (pthread_t *)malloc(args.threads * sizeof(pthread_t));
    Stats *all_stats = (Stats *)calloc(args.threads, sizeof(Stats));

    for (int i = 0; i < args.threads; ++i) {
        if (pthread_create(&threads[i], NULL, process_file, &args) != 0) {
            perror("pthread_create");
            return EXIT_FAILURE;
        }
    }

    for (int i = 0; i < args.threads; ++i) {
        Stats *thread_stats;
        if (pthread_join(threads[i], (void **)&thread_stats) != 0) {
            perror("pthread_join");
            return EXIT_FAILURE;
        }
        for (int j = 0; j < 256; ++j) {
            all_stats->total_bases[j] += thread_stats->total_bases[j];
        }
        all_stats->total_reads += thread_stats->total_reads;
        all_stats->q20_bases += thread_stats->q20_bases;
        all_stats->q30_bases += thread_stats->q30_bases;
        free(thread_stats);
    }

    write_stats(args.output_file, args.sample_name, all_stats);

    free(threads);
    free(all_stats);

    return EXIT_SUCCESS;
}
