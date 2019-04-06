#ifndef _BST_HPP_
#define _BST_HPP_

#include <string>

namespace tree
{
    template <class T>
    class BST
    {
        public:
            BST(int key, T value);
            void insert(int key, T value); //updates value if key exists
            void remove(int key);
            bool contains(int key);
            std::string keys_in_order();
            T* get(int key);

        private:

        protected:
            int key;
            T value;
            BST *left;
            BST *right;
            BST *InOrder(int key);
    };

    template <class T>
    BST<T>::BST(int key, T value)
    {
        this->key = key;
        this->value = value;
        this->left = nullptr;
        this->right = nullptr;
    }

    template <class T>
    void BST<T>::insert(int key, T value)
    {
        if (this->key == key)
            this->value = value;
        else
        {
            if (key < this->key)
            {
                if (this->left)
                {
                    this->left->insert(key, value);
                }
                else
                {
                    this->left = new BST<T>(key, value);
                }
            }
            else
            {
                if (this->right)
                {
                    this->right->insert(key, value);
                }
                else
                {
                    this->right = new BST<T>(key, value);
                }
            }
        }
    }

    template <class T>
    void BST<T>::remove(int key)
    {
      //TODO: define function  
    };

    template <class T>
    std::string BST<T>::keys_in_order()
    {
        char buf[100];
        std::string out;

        if (this->left)
            out += this->left->keys_in_order();

        sprintf(buf, "%d ", this->key);
        out += buf;

        if (this->right)
            out += this->right->keys_in_order();

        return out;
    }

    template <class T>
    BST<T>* BST<T>::InOrder(int key)
    {
        BST<T>* tree = nullptr;

        if (this->left)
        {
             tree = this->left->InOrder(key);
             if (tree) return tree;
        }

        if (this->key == key)
        {
             return this;
        }

        if (this->right)
        {
             tree = this->right->InOrder(key);
        }

        return tree;
    }

    template <class T>
    T* BST<T>::get(int key)
    {
        BST<T>* v = this->InOrder(key);

        if (v)
            return &(v->value);
        else
            return nullptr;

        return v ? &(v->value) : nullptr;
    }

    template <class T>
    bool BST<T>::contains(int key)
    {
        return this->InOrder(key) ? true : false;
    }
};

#endif //_BST_HPP_