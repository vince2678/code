#ifndef _HASH_TABLE_H_
#define _HASH_TABLE_H_

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
    unsigned (*hash)(struct hash_table_t *, char *key);
    int (*insert)(struct hash_table_t *, char *key, void *value);
    void* (*search)(struct hash_table_t *, char *key);
    void* (*delete)(struct hash_table_t *, char *key);
    float (*load_factor)(struct hash_table_t *);
} hash_table;

struct hash_table_t *new_hash_table();

#endif //_HASH_TABLE_H_