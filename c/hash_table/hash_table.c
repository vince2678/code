#include "hash_table.h"

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <time.h>

int A = 0;
int B = 0;
int C = 0;
int F = 0;

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

 int large_primes[] =
 {4254587, 4255061, 4255477, 4255817, 4254599, 4255067,
 4255501, 4255859, 4254623, 4255073, 4255519, 4255877,
 4254629, 4255079, 4255523, 4255879, 4254637, 4255081,
 4255541, 4255913, 4254643, 4255087, 4255549, 4255921,
 4254647, 4255093, 4255553, 4255931, 4254671, 4255109,
 4255561, 4255939, 4254683, 4255133, 4255577, 4255949,
 4254707, 4255157, 4255579, 4255963, 4254739, 4255169,
 4255583, 4255987, 4254763, 4255187, 4255591, 4255997,
 4254779, 4255193, 4255597, 4256003, 4254797, 4255213,
 4255609, 4256009, 4254799, 4255249, 4255619, 4256029,
 4254821, 4255301, 4255637, 4256051, 4254853, 4255313,
 4255673, 4256089, 4254869, 4255351, 4255679, 4256101,
 4254883, 4255369, 4255697, 4256117, 4254911, 4255387,
 4255739, 4256141, 4254949, 4255399, 4255747, 4256159,
 4254961, 4255403, 4255751, 4256167, 4254983, 4255429,
 4255781, 4256191, 4255039, 4255439, 4255789, 4256227,
 4255057, 4255451, 4255807, 4256233
 };

unsigned hash(int modulus, char *key)
{
    unsigned ix = F;

    char *s = key;

    while (*s)
    {
        ix = (ix * A) ^ (*s * B);
        s++;
    };

    ix = ix % C;

    if (modulus > 0)
        ix = ix % modulus;

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
    hash_table_ll **table = calloc(m, sizeof(hash_table_ll*));

    if (!table)
    {
        perror("calloc");
        return NULL;
    }

    for (int i = 0; i < m; i++)
    {
        table[i] = NULL;
    }

    return table;
}

int insert_into_table(int flags, struct hash_table_ll_t **table, unsigned index, char *key, void *value)
{
    hash_table_ll *prev = NULL;
    hash_table_ll *curr = table[index];

    while (curr)
    {
        if (strcmp(key, curr->key) == 0)
        {
            curr->value = value;
            return INSERT_KEY_EXISTS;
        }

        prev = curr;
        curr = curr->next;
    }

    hash_table_ll *new = malloc(sizeof(hash_table_ll)); 

    if (!new)
    {
        perror("malloc");
        return INSERT_KEY_FAILURE;
    }

    if (flags & COPY_KEY_ON_INSERT)
    {
        new->key = calloc((strlen(key) + 1), sizeof(char));
        if (!new->key)
        {
            perror("calloc");
            free(new);
            return INSERT_KEY_FAILURE;
        }
        strcpy(new->key, key);
    }
    else
    {
        new->key = key;
    }

    new->value = value;
    new->next = NULL;

    if (prev) /* linked list was already initialised */
        prev->next = new;
    else /* linked list was not initialised */
        table[index] = new;

    return INSERT_KEY_SUCCESS;
}

void * destroy_ll_node(int flags, hash_table_ll *head)
{
    hash_table_ll *next = head->next;

    if (flags & FREE_VALUE_ON_DELETE)
        free(head->value);

    if (flags & FREE_KEY_ON_DELETE)
        free(head->key);

    free(head);

    return next;
}

void destroy_ll_table(int flags, hash_table_ll **table, int len)
{
    for (int i = 0; i < len; i++)
    {
        hash_table_ll *head = table[i];

        while (head)
            head = destroy_ll_node(flags, head);
    }
    free(table);
}

void destroy_hash_table(hash_table *t)
{
    destroy_ll_table(t->flags, t->table, t->physical_size);
    free(t);
}

int rehash_table(struct hash_table_t *t)
{
    int new_size;

    if (t->load_factor(t) >= MAX_LOAD)
        new_size = t->size * GROWTH_FACTOR;
    else if (t->size > INIT_SIZE && (t->load_factor(t) <= SHRINK_LOAD))
        new_size = t->physical_size * SHRINK_FACTOR;
    else
        return REHASH_UNNECESSARY;

    hash_table_ll **new_table = initialise_ll(new_size);

    if (!new_table)
        return REHASH_FAILED;

    for (int i = 0; i < t->physical_size; i++)
    {
        hash_table_ll *head = t->table[i];

        while (head)
        {
            unsigned index = hash(new_size , head->key);
            int retval = insert_into_table(t->flags, new_table, index, head->key, head->value);

            if (retval == INSERT_KEY_FAILURE)
            {
                destroy_ll_table(t->flags, new_table, new_size);
                return REHASH_FAILED;
            }
            head = destroy_ll_node(t->flags, head);
        }
    }
    free(t->table);
    t->table = new_table;
    t->physical_size = new_size;

    return REHASH_SUCCESS;
}

int insert(struct hash_table_t *t, char *key, void *value)
{
    int retval = rehash_table(t);

    if (retval == REHASH_FAILED)
        return INSERT_KEY_FAILURE;

    unsigned ix = t->hash(t->physical_size, key);
    retval = insert_into_table(t->flags, t->table, ix, key, value);

    if (retval == INSERT_KEY_SUCCESS)
        t->size += 1;

    return 0;
}

void * search(struct hash_table_t *t, char *key)
{
    unsigned ix = t->hash(t->physical_size, key);

    void *data = NULL;

    hash_table_ll * curr = NULL;

    curr = t->table[ix];

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

void * delete(struct hash_table_t *t, char *key)
{
    rehash_table(t);

    unsigned ix = t->hash(t->physical_size, key);

    void *value = NULL;

    hash_table_ll *prev = NULL;
    hash_table_ll *curr = t->table[ix];

    while(curr)
    {
        if (strcmp(key, curr->key) == 0)
        {
            if (prev)
            {
                prev->next = destroy_ll_node(t->flags, curr);
            }
            else
            {
                t->table[ix] = destroy_ll_node(t->flags, curr);
            }

            t->size -= 1;
            break;
        }
        prev = curr;
        curr = curr->next;
    }
    return value;
}

void print_table(hash_table *t)
{
    int collisions = 0;
    int empty = 0;
    for (int i = 0; i < t->physical_size; i++)
    {
        printf("\t%i\n", i);
        hash_table_ll *next = t->table[i];
        int count = 0;

        while(next)
        {
            printf("\t|\n");
            printf("\t---> ");
            printf("'%s'\n", next->key);
            count += 1;
            next = next->next;
        }
        if (count > 1)
        {
            printf("\tCollisions at index %i: %i\n", i, count-1);
            collisions += count - 1;
        }
        else
        {
            empty = empty + 1;
        }
        printf("\n");
    }
    printf("Total # of collisions: %i\n", collisions);
    printf("Total # of elements: %i\n", t->size);
    printf("Physical array size: %i\n", t->physical_size);
    printf("Empty slots: %i\n", empty);

    if (t->size)
        printf("collisions/size: %.2f\n", (float) collisions / t->size);

    printf("Load factor: %.2f\n", t->load_factor(t));
    printf("\n");
}

struct hash_table_t* new_hash_table(int flags)
{
    hash_table *t = malloc(sizeof(hash_table));

    if (!t)
    {
        perror("malloc");
        return NULL;
    };

    if (!(t->table = initialise_ll(INIT_SIZE)))
        return NULL;

    t->physical_size = INIT_SIZE;
    t->size = 0;
    t->flags = flags;
    t->hash = &hash;
    t->delete = &delete;
    t->insert = &insert;
    t->load_factor = &load_factor;
    t->search = &search;

    int prime_len = sizeof(primes)/sizeof(int) - 1;
    int lprime_len = sizeof(large_primes)/sizeof(int) - 1;

    /* seed rng */
    srand(time(NULL));

    /* get primes */
    if (A == 0)
    {
        A = primes[rand() % prime_len];
        B = primes[rand() % prime_len];

        /* use larger primes for initial value
           and modulus used by hash */
        C = large_primes[rand() % lprime_len];
        F = large_primes[rand() % lprime_len];
    }

    return t;
}