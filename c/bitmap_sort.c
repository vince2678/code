#include <stdio.h> // file ops
#include <stdlib.h> //strtol
#include <unistd.h> // getopt
#include <getopt.h> // getopt
//#include <math.h> //pow, ceil

#ifndef __CHAR_BIT__
#define __CHAR_BIT__ 8
#endif

#ifndef _POSIX_C_SOURCE
#define _POSIX_C_SOURCE 200809L
#endif

#define ENABLE_STDIO 1

int power(int x, int y)
{
    if (y == 0)
        return 1;
    
    int result = x * power(x, y - 1);

    return result;
}

int main(int argc, char **argv)
{
    typedef int bool;

    bool sort;

    char *bitmap;
    char *filename;
    char *optstring;

    int bitmap_size;
    int g; // number of #s to generate
    int n; // max # of #s, and max size of number
    int opt;

    filename = NULL;
    optstring = "hg::sn:f:";
    n = power(10, 7);
    sort = 1;


#if 0
    if (argc < 2)
    {
        fprintf(stderr, "Usage: %s [-g|-s] [-n] n [-f] filename\n", argv[0]);
        return 1;
    }
#endif

    while((opt = getopt(argc, argv, optstring)) != -1)
    {
        switch(opt)
        {
            case 'n':
                n = strtol(argv[optind], NULL, 10); 
                break;
            case 'f':
                filename = argv[optind];
                break;
            case 's':
                sort = 1;
                break;
            case 'g':
                sort = 0;
                g = strtol(argv[optind], NULL, 10); 
                if (g == 0)
                    g = n;
                break;
            default:
                fprintf(stderr, "Usage: %s [-g|-s] [-n] n [-f] filename\n", argv[0]);
                return 1;
        }
    };
    
    bitmap_size = n / __CHAR_BIT__;
    bitmap_size = bitmap_size + 1; //round up

    bitmap = malloc (bitmap_size);

    if (!bitmap)
    {
        perror("malloc");
        return 1;
    }

    // initialise bitmap memory
    for (int i = 0; i < bitmap_size; i++)
        bitmap[i] = 0;

    FILE *fin;
    FILE *fout;

#if ENABLE_STDIO
    fin = stdin;
    fout = stdout;
#endif

    if (sort)
    {
        if (filename && !(fin = fopen(filename, "r+")))
        {
            perror("fopen");
            return 1;
        }

        char *line;

        int a;
        int b;
        int nread;
        size_t lsize;

        int num;

        lsize = 256;
        num = 0;

        if (!(line = malloc(lsize)))
        {
            perror("malloc");
            return 1;
        }

        while ((nread = getline(&line, &lsize, fin)) != -1)
        {
            num = strtol(line, NULL, 10);
            if (num >= n)
                continue;
            
            a = num / __CHAR_BIT__;
            b = num % __CHAR_BIT__;

            bitmap[a] = bitmap[a] | (1 << b);
        }

#if ENABLE_STDIO
        if (fileno(fin) != fileno(stdin))
        {
#endif
            fout = fin;
            fseek(fout, 0, SEEK_SET);
#if ENABLE_STDIO
        }
#endif

        for (num = 0; num < bitmap_size; num++)
        {
            a = num / __CHAR_BIT__;
            b = num % __CHAR_BIT__;

            if (bitmap[a] & (1 << b))
            {
                fprintf(fout, "%d\n", num);
            }
        }

#if ENABLE_STDIO
        if (fileno(fout) != fileno(stdout))
#endif
            fclose(fout);
    }
    else // generating random integers
    {
        //TODO: Add flag for specifying max #s to generate
    }

    /* Algorithm:

        - Read file
        - Read each line and convert str to int
        - mark appropriate bit in bitmap
        - write to file, looping through every bit in bitmap

    */

    return 0;
};