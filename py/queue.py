from ll import LLNode

class Queue:

    def __init__(self, elems = []):
        self.start = None

        for data in elems:
            self.enqueue(data)
    
    def enqueue(self, data):

        if self.start == None:
            self.start = LLNode(data)
        else:
            self.start.add(data)
        
    def dequeue(self):

        ret = None

        assert (self.start != None), "Queue is empty!"
        
        p = self.start
        n = p.next
        ret = p.data

        self.start = n

        del p

        return ret
    
    def peek(self):

        assert (self.start != None), "Queue is empty!"

        return self.start.data

    def __str__(self):
        
        s = ""

        if self.start == None:
            return "Queue([])"

        n = self.start.next

        s += "Queue([{}".format(self.start.data)

        while n != None:
            s += ", {}".format(n.data)
            n = n.next
        
        s += "])"
        
        return s

    def __repr__(self):
        return self.__str__()