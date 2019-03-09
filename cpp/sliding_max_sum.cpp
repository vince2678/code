#include <iostream>
#include <vector>

using namespace std;

int main(int argc, char** argv) {

    int k, n;
    int in;
    vector<int> arr;

    cout << "\nEnter the number of #s to sum at a time: ";
    cin >> k;

    cout << "\nEnter the number of #s to be counted over: ";
    cin >> n;

    if (n < k) {
        cout << "\nTotal number of #s should be greater than window size";
        return EXIT_FAILURE;
    }

    int sum = 0;
    int max = INT32_MIN;
    int count = 0;
    int ix = 0;

    for (int i=0; i < n; i++) {
        cout << "Enter the next number to sum over: ";
        cin >> in;
        arr.push_back(in);
        
        if (count < k) {
            sum += arr[i];
            count++;
            continue;
        }

        if (max < sum)
            max = sum;

        sum -= arr[ix];
        sum += arr[i];
        ix++;
    }

    cout << "Maximum sum is" << (max > sum ? max : sum) << "\n";
};