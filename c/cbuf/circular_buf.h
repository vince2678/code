#ifndef _CIRCULAR_BUF_H_
#define _CIRCULAR_BUF_H_

typedef struct circular_buf_t
{
    int pos;
    int size;
    int capacity;
    void *buf;

    void *(*get)(struct circular_buf_t *cbuf, int index);
    void *(*pop)(struct circular_buf_t *cbuf);
    int (*push)(struct circular_buf_t *cbuf, void * data);
} circular_buf;

struct circular_buf_t *new_circular_buf(int capacity);
void delete_circular_buf(struct circular_buf_t *cbuf);

#endif //_CIRCULAR_BUF_H_