#include "hash_table.h"
#include "stdio.h"
#include <assert.h>

int test_insert(hash_table *t, char **keys, int *values, int n)
{
    int old_size;
    int *val;

    for (int i = 0; i < n; i++)
    {
        old_size = t->size;
        val = t->search(t, keys[i]);

        t->insert(t, keys[i], &values[i]);

        if (val) // an update operation
        {
            assert(old_size == t->size);
#ifdef VERBOSE
            fprintf(stderr, "%s: updated key %s, old value %i, new value %i\n", __func__, keys[i], *val, values[i]);
#endif
        }
        else // new insertion
        {
            assert(t->size == (old_size + 1));
            val = t->search(t, keys[i]);
            assert(*val == values[i]);
#ifdef VERBOSE
            fprintf(stderr, "%s: new key %s, value %i\n", __func__, keys[i], values[i]);
#endif
        }
    }
    return 0;
}

int test_delete(hash_table *t, char **keys, int n)
{
    int old_size;
    int *old_val, *new_val;

    for (int i = 0; i < n; i++)
    {
        old_size = t->size;
        old_val = t->search(t, keys[i]);
        t->delete(t, keys[i]);
        new_val = t->search(t, keys[i]);

        if (old_val) // key in table
        {
            assert(old_size == (t->size + 1));
            assert(new_val == NULL);
#ifdef VERBOSE
            fprintf(stderr, "%s: Key %s with value %i deleted\n", __func__, keys[i], *old_val);
#endif
        }
        else // unkown key
        {
            assert(t->size == old_size);
            assert(old_val == new_val);
            assert(old_val == NULL);
#ifdef VERBOSE
            fprintf(stderr, "%s: Key %s not in table\n", __func__, keys[i]);
#endif
        }
    }
    return 0;
}

int main(int argc, char **argv)
{
    hash_table *t = new_hash_table();

    char *keys[] = {"one", "two", "three", "four", "five", "one"};
    int values[] = {1,2,3,4,5,-1};

    // insert then delete all keys
    test_insert(t, keys, values, 6);
    test_delete(t, keys, 6);
    assert(t->size == 0);

    return 0;
}