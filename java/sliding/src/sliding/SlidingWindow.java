package sliding;

import java.util.ArrayList;
import java.util.List;

public class SlidingWindow {

    public static int get_sum(int k, List<Integer> arr) {
        int max = Integer.MIN_VALUE;
        int sum = 0;

        int ix = 0;
        int count = 0;

        for (int i=0; i < arr.size(); i++) {
            if (count < k) {
                sum += arr.get(i);
                count++;
                continue;
            }

            if (max < sum) max = sum;

            sum -= arr.get(ix);
            sum += arr.get(i);
            ix++;
        }
        return max > sum ? max : sum;
    }

    public static void main(String[] args) {

        int k;
        int n;
        String s;
        ArrayList<Integer> arr = new ArrayList<Integer>();

        System.out.println("Input window size: ");
        s = System.console().readLine();
        k = Integer.parseInt(s);
        
        System.out.println("Input total count of numbers: ");
        s = System.console().readLine();
        n = Integer.parseInt(s);

        if (n < k) {
            System.out.println("Total count should be greater than window size");
            System.exit(1);
        }

        for (int i=0; i < n; i++) {
            System.out.println("Input next number: ");
            s = System.console().readLine();
            arr.add(Integer.parseInt(s));
        }

        int sum = SlidingWindow.get_sum(k, arr);

        System.out.println(String.format("Largest sum over %d integers is %d", k, sum));
    }
}