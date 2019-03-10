#include <iostream>
#include "bst.hpp"

using namespace std;

int main(int argc, char **argv)
{
    int root = 5;
    int nums[] = {8,10,11,6,2,7,4,1,3};

    tree::BST<string> bst = tree::BST<string>(root, "");

    for (int i=0; i < sizeof(nums)/sizeof(int); i++)
    {
        bst.insert(nums[i], "");
    }
    cout << bst.keys_in_order() << endl;
}