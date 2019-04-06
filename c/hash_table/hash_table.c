#include "hash_table.h"

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
//#include <errno.h>

#define INIT_SIZE 17

#define A 3931
#define B 4409
#define C 3673
#define F 4079

int primes[] =
{3581, 3779, 4001, 4211, 3583, 3793, 4003, 4217, 3593,
 3797, 4007, 4219, 3607, 3803, 4013, 4229, 3613, 3821,
 4019, 4231, 3617, 3823, 4021, 4241, 3623, 3833, 4027,
 4243, 3631, 3847, 4049, 4253, 3637, 3851, 4051, 4259,
 3643, 3853, 4057, 4261, 3659, 3863, 4073, 4271, 3671,
 3877, 4079, 4273, 3673, 3881, 4091, 4283, 3677, 3889,
 4093, 4289, 3691, 3907, 4099, 4297, 3697, 3911, 4111,
 4327, 3701, 3917, 4127, 4337, 3709, 3919, 4129, 4339,
 3719, 3923, 4133, 4349, 3727, 3929, 4139, 4357, 3733,
 3931, 4153, 4363, 3739, 3943, 4157, 4373, 3761, 3947,
 4159, 4391, 3767, 3967, 4177, 4397, 3769, 3989, 4201,
 4409};

int hash(struct hash_table_t *t, char *key)
{
    int ix = 0;
    // TODO: Implement a hash function.
    // Hint: use mod arithetic with some algebraic function
    return ix;
}


float load_factor(struct hash_table_t *t)
{
    float alpha = t->size / (float) t->physical_size;
    return alpha;
}

//TODO: Use a bit array with bit masks to indicate used slots
struct hash_table_ll_t ** initialise_ll(int m)
{
    hash_table_ll **data = malloc(sizeof(hash_table_ll*) * m);

    if (!data)
    {
        perror("malloc");
        exit(-EXIT_FAILURE);
    }

    for (int i = 0; i < m; i++)
    {
        data[i] = NULL;
    }

    return data;
}

//TODO: Determine if re-hash of entire table is necessary
int insert(struct hash_table_t *t, char *key, void *value)
{
    int ix = t->hash(t, key);

    if (!t->data)
    {
        t->data = initialise_ll(INIT_SIZE);
        t->physical_size = INIT_SIZE;
        t->size = 0;
    }

    hash_table_ll *prev = NULL;
    hash_table_ll *curr = t->data[ix];

    while (curr)
    {
        if (strcmp(key, curr->key))
        {
            curr->value = value;
            return 0;
        }

        prev = curr;
        curr = curr->next;
    }

    hash_table_ll *new = malloc(sizeof(hash_table_ll)); 

    if (!new)
    {
        perror("malloc");
        exit(-EXIT_FAILURE);
    }

    new->key = malloc(sizeof(char) * (strlen(key)+1));
    if (!new->key)
    {
        perror("malloc");
        exit(-EXIT_FAILURE);
    }
    strcpy(new->key, key);

    new->value = value;
    new->next = NULL;

    t->size += 1;

    if (prev) /* linked list was already initialised */
        prev->next = new;
    else /* linked list was not initialised */
        t->data[ix] = new; 

    return 0;
}

void * search(struct hash_table_t *t, char *key)
{
    int ix = t->hash(t, key);

    void *data = NULL;

    hash_table_ll * curr = NULL;

    if (t->data)
    {
        curr = t->data[ix];
    }
    else
    {
        t->data = initialise_ll(INIT_SIZE);
        t->physical_size = INIT_SIZE;
        t->size = 0;
    };

    while (curr)
    {
        if (strcmp(key, curr->key) == 0)
        {
            data = curr->value;
            break;
        }
        curr = curr->next;
    }
    return data;
}

//TODO: Determine if re-hash of entire table is necessary
void * delete(struct hash_table_t *t, char *key)
{
    int ix = t->hash(t, key);

    void *value = NULL;

    hash_table_ll *prev = NULL;
    hash_table_ll *curr = t->data[ix];

    while(curr)
    {
        if (strcmp(key, curr->key) == 0)
        {
            if (prev)
            {
                prev->next = curr->next;
            }
            else
            {
                t->data[ix] = curr->next;
            }
            value = curr->value;
            free(curr->key);
            free(curr);
            t->size -= 1;
            break;
        }
        prev = curr;
        curr = curr->next;
    }
    return value;
}