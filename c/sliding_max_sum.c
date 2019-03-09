#include <stdio.h>
#include <strings.h>
#include <stdlib.h>
#include <errno.h>
#include <err.h>
#include <limits.h>

int main(int argc, char** argv) {

    char in[sizeof(int)+1];
    int i, k, n;
    int *arr;

    printf("\nEnter the number of #s to sum at a time: " );
    fgets(&in, sizeof(int)+1, stdin);
    k = strtol(in, NULL, 10);


    do {
        printf("\nEnter the total number of #s being summed over: " );
        fgets(&in, sizeof(int)+1, stdin);
        n = strtol(in, NULL, 10);
    } while (n < k);

    if (!(arr = (int*) malloc(sizeof(int)*n))) {
        err(errno, NULL);
    }

    int max = INT_MIN; 
    int sum = 0;
    int fpos = 0;
    int count = 0;

    for (i=0;i < n;i++) {
        printf("\nEnter the next number to sum over (%i left): ", (n - i));
        fgets(&in, sizeof(int)+1, stdin);
        arr[i] = strtol(in, NULL, 10);

        if (count < k) {
            sum += arr[i];
            count++;
            continue;
        }

        if (max < sum)
            max = sum;
        
        sum -= arr[fpos];
        sum += arr[i];
        fpos++;
    }

    free(arr);

    printf ("Maximum sum over %i numbers is %i\n", k, max);
}