#include <iostream>
#include "bst.hpp"
#include <string>

using namespace std;

int main(int argc, char **argv)
{
    int root = 5;
    int nums[] = {8,10,11,6,2,7,4,1,3};

    tree::BST<string> bst = tree::BST<string>(root, "Number " + to_string(root));

    for (int i=0; i < sizeof(nums)/sizeof(int); i++)
    {
        bst.insert(nums[i], "Number " + to_string(nums[i]));
    }
    cout << bst.keys_in_order() << endl;

    for (int i=0; i < sizeof(nums)/sizeof(int); i++)
    {
        if (bst.get(nums[i]))
            cout << *bst.get(nums[i]) << endl;
    }

    for (int i=0; i < 20; i++)
    {
        if (bst.contains(i))
            cout << "Number " << to_string(i) << " is contained in the tree" << endl;
        else
            cout << "Number " << to_string(i) << " is not contained in the tree" << endl;
    }
}