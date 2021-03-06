#include "circular_buf.h"

#include <stdio.h> /* NULL, perror */
#include <stdlib.h> /* free, malloc, calloc */

void *get(struct circular_buf_t *cbuf, int index)
{
    int adj_i;
    void *data;

    adj_i = index % cbuf->capacity;
    data = cbuf->buf[adj_i];

    return data;
}

void *pop(struct circular_buf_t *cbuf)
{
    if (cbuf->size == 0)
        return NULL;

    void *data;

    data = cbuf->buf[cbuf->pos];
    cbuf->pos = (cbuf->pos + 1) % cbuf->capacity;
    cbuf->size = cbuf->size - 1;

    return data;
}
int push(struct circular_buf_t *cbuf, void * data)
{
    int i;

    if (cbuf->size < cbuf->capacity)
    {
        i = cbuf->size;
        cbuf->size = i + 1;
    }
    else
    {
        i = cbuf->pos;
        cbuf->pos = (i + 1) % cbuf->capacity;
    }

    cbuf->buf[i] = data;

    return 0;
}

struct circular_buf_t *new_circular_buf(int capacity)
{
    void **buf;
    circular_buf *cbuf;

    buf = calloc(capacity, sizeof(void *));

    if (buf == NULL)
    {
        perror("calloc");
        return NULL;
    }

    cbuf = malloc(sizeof(circular_buf));

    if (cbuf == NULL)
    {
        perror("malloc");
        free(buf);
        return NULL;
    }

    cbuf->buf = buf;
    cbuf->capacity = capacity;
    cbuf->get = &get;
    cbuf->pop = &pop;
    cbuf->push = &push;
    cbuf->size = 0;

    return cbuf;
}

void delete_circular_buf(struct circular_buf_t *cbuf)
{
    free(cbuf->buf);
    free(cbuf);
}