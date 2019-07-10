#include <stdio.h>
#include <stdlib.h>

double abs_d(double a)
{
    if (a < 0)
        a = a * -1;
    
    return a;
}

int main(int argc, char **argv)
{
    double a, b, eps, delta, sq, sqrt;
    double newsq;

    a = 0;
    b = 0;
    eps = __INT8_MAX__;
    delta = 0.00005;
    sq = 0;
    sqrt = 0;

    if (argc < 2)
    {
        printf("Usage: %s [square]\n", argv[0]);
        return 1;
    };

    sq = strtod(argv[1], NULL);
    b = sq;

    while (eps > delta)
    {
        sqrt = (b + a)/2;

        newsq = sqrt * sqrt;

        if (newsq > sq)
            b = sqrt;
        else if (newsq < sq)
            a = sqrt; 

        eps = newsq - sq;
        eps = abs_d(eps);
    }

    printf("sqrt: %.5f, delta: %.5f, eps: %.5f\n\n", sqrt, delta, eps);

    return 0;
}