#include "circular_buf.h"

#include <assert.h> /* assert */
#include <stdlib.h> /* strtol */
#include <stdio.h> /* perror, printf */

void test_push(int capacity)
{
    circular_buf *cbuf;

    cbuf = new_circular_buf(capacity);

    if (cbuf == NULL)
    {
        fprintf(stderr, "%s: Failed to allocate memory for buffer\n", __func__);
        return;
    }

    int *nums = calloc(capacity, sizeof(int));

    if (nums == NULL)
    {
        perror("calloc");
        fprintf(stderr, "%s: Failed to allocate memory\n", __func__);
        delete_circular_buf(cbuf);
        return;
    }

    int a, b, *c;

    for (int i = 0; i < capacity; i++)
    {
        nums[i] = i + 1;

        a = cbuf->pos;
        b = cbuf->size;

        cbuf->push(cbuf, nums + i);
        c = (int *)(cbuf->get(cbuf, i));

        assert(cbuf->pos == a);
        assert(cbuf->size == b + 1);
        assert(*c == nums[i]);
    }

    assert(cbuf->size == capacity);

    for (int i = 0; i < capacity; i++)
    {
        a = cbuf->pos;

        nums[i] = nums[i] * 2;

        cbuf->push(cbuf, nums + i);
        c = (int *)(cbuf->get(cbuf, i));

        assert(cbuf->size == capacity);
        assert(cbuf->pos == ((a + 1) % capacity));
        assert(*c == nums[i]);
    }
}

void test_pop(int capacity)
{
    circular_buf *cbuf;

    cbuf = new_circular_buf(capacity);

    if (cbuf == NULL)
    {
        fprintf(stderr, "%s: Failed to allocate memory for buffer\n", __func__);
        return;
    }

    int *nums = calloc(capacity, sizeof(int));

    if (nums == NULL)
    {
        perror("calloc");
        fprintf(stderr, "%s: Failed to allocate memory\n", __func__);
        delete_circular_buf(cbuf);
        return;
    }

    int a, b, *c;

    for (int i = 0; i < capacity; i++)
    {
        nums[i] = i + 1;
        cbuf->push(cbuf, nums + i);
    }

    for (int i = 0; i < capacity; i++)
    {
        a = cbuf->pos;
        b = cbuf->size;
        c = (int *)(cbuf->pop(cbuf));

        assert(cbuf->pos == (a + 1) % capacity);
        assert(cbuf->size == b - 1);
        assert(*c == nums[i]);
    }
}

int main(int argc, char **argv)
{
    int capacity;

    if (argc < 2)
        capacity = 100;
    else
        capacity = strtol(argv[1], NULL, 10);

    test_push(capacity);
    test_pop(capacity);

    return 0;
}