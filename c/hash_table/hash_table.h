#ifndef _HASH_TABLE_H_
#define _HASH_TABLE_H_

#define INIT_SIZE 17
#define MAX_LOAD 2
#define SHRINK_LOAD (1.0/MAX_LOAD)
#define GROWTH_FACTOR 1.5
#define SHRINK_FACTOR (1.0/GROWTH_FACTOR)

#define INSERT_KEY_SUCCESS 0
#define INSERT_KEY_EXISTS 1
#define INSERT_KEY_FAILURE 2

#define REHASH_SUCCESS 0
#define REHASH_UNNECESSARY 1
#define REHASH_FAILED 2

#define FREE_KEY_ON_DELETE (1)
#define COPY_KEY_ON_INSERT (3)
#define FREE_VALUE_ON_DELETE (4)

// TODO: use a doubly linked list for faster deletion
typedef struct hash_table_ll_t {
    char *key;
    void *value;
    struct hash_table_ll_t *next;
} hash_table_ll;

typedef struct hash_table_t {
    int flags;
    int physical_size;
    int size;
    struct hash_table_ll_t **table;
    unsigned (*hash)(int, char *key);
    int (*insert)(struct hash_table_t *, char *key, void *value);
    void* (*search)(struct hash_table_t *, char *key);
    void* (*delete)(struct hash_table_t *, char *key);
    float (*load_factor)(struct hash_table_t *);
} hash_table;

struct hash_table_t *new_hash_table(int flags);
void destroy_hash_table(hash_table *t);
void print_table(hash_table *t);

#endif //_HASH_TABLE_H_