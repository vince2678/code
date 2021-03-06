#include "hash_table.h"
#include <stdio.h>
#include <assert.h>
#include <stdlib.h>

#define STR_SIZE 256

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

int test_growth(int flags)
{
    int old_size;
    char *val;

    hash_table *t = new_hash_table(flags);

    int n = t->physical_size * MAX_LOAD;

    for (int i = 0; i < n; i++)
    {
        char *key = malloc(sizeof(char) * STR_SIZE);

        snprintf(key, STR_SIZE, "%i%i", i, i);
        key[STR_SIZE - 1] = 0;

        old_size = t->size;
        val = t->search(t, key);

        t->insert(t, key, key);

        assert(t->size == (old_size + 1));
        val = t->search(t, key);
        assert(val == key);
    }

    assert(t->load_factor(t) == MAX_LOAD);
    assert(t->size == n);

#ifdef VERBOSE
    fprintf(stderr, "\nGrowth test:\n");
    print_table(t);
#endif

    for (int i = n; i < MAX_LOAD * n; i++)
    {
        char *key = malloc(sizeof(char)*6);

        snprintf(key, 6, "%i%i", i, i);
        key[5] = 0;

        old_size = t->size;
        val = t->search(t, key);

        t->insert(t, key, key);

        assert(t->size == (old_size + 1));
        val = t->search(t, key);
        assert(val == key);
    }
    /* since we can't test that the load_factor() is MAX_LOAD/GROWTH_FACTOR
       directly because of rounding, test the size and physical size instead */
    assert(t->size == MAX_LOAD * n);
    assert(t->physical_size == GROWTH_FACTOR * n);

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
    int flags = 0;

    hash_table *t = new_hash_table(flags);

    char *keys[] = {"one", "two", "three", "four", "five", "one"};
    int values[] = {1,2,3,4,5,-1};

    // insert then delete all keys
    test_insert(t, keys, values, 6);
    test_delete(t, keys, 6);
    assert(t->size == 0);

    test_growth(flags);

    flags = COPY_KEY_ON_INSERT;
    t->flags = flags;

    test_insert(t, keys, values, 6);
    test_delete(t, keys, 6);
    assert(t->size == 0);

    test_growth(flags);

    return 0;
}