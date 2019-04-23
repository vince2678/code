#ifndef _HASH_TABLE_H_
#define _HASH_TABLE_H_

#define INIT_SIZE 17
#define MAX_LOAD 2
#define SHRINK_LOAD (1.0/MAX_LOAD)
#define GROWTH_FACTOR 1.5
#define SHRINK_FACTOR (1.0/GROWTH_FACTOR)

// TODO: use a doubly linked list for faster deletion
typedef struct hash_table_ll_t {
    char *key;
    void *value;
    struct hash_table_ll_t *next;
} hash_table_ll;

typedef struct hash_table_t {
    int physical_size;
    int size;
    struct hash_table_ll_t **data;
    unsigned (*hash)(int, char *key);
    int (*insert)(struct hash_table_t *, char *key, void *value);
    void* (*search)(struct hash_table_t *, char *key);
    void* (*delete)(struct hash_table_t *, char *key);
    float (*load_factor)(struct hash_table_t *);
} hash_table;

struct hash_table_t *new_hash_table();
void print_table(hash_table *t);

#endif //_HASH_TABLE_H_