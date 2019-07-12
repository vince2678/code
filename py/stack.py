from ll import DLLNode

class Stack:

    def __init__(self, elems = []):
        self.start = None
        self.length = 0

        for data in elems:
            self.push(data)

    def push(self, data):

        if self.start == None:
            self.start = DLLNode(data)
        else:
            prev = self.start.prev
            node = DLLNode(data)

            node.next = self.start
            node.prev = prev
            prev.next = node
            self.start.prev = node
    
        self.length = self.length + 1
    
    def pop(self):

        assert (self.start != None), "There are no elements on the stack!"

        ret = None

        if self.start == self.start.next:
            ret = self.start.data
            del self.start
            self.start = None
        else:
            node = self.start.prev
            newprev = node.prev

            self.start.prev = newprev
            newprev.next = self.start

            ret = node.data
            del node

        self.length = self.length - 1

        return ret

    def peek(self):

        assert (self.start != None), "There are no elements on the stack!"

        ret = None

        if self.start == self.start.next:
            ret = self.start.data
        else:
            node = self.start.prev
            ret = node.data

        return ret

    def __len__(self):
        return self.length

    def __str__(self):
        
        s = ""

        if self.start == None:
            return "Stack([])"

        n = self.start.next

        s += "Stack([{}".format(self.start.data)

        while n != self.start:
            s += ", {}".format(n.data)
            n = n.next
        
        s += "])"
        
        return s

    def __repr__(self):
        return self.__str__()
        