class LLNode:

    def __init__(self, data):
        self.data = data
        self.next = None

    def add(self, data):
        node = LLNode(data)

        n = self

        while (n.next != None):
            n = n.next
        
        n.next = node

    def __repr__(self):

        s = "LLNode({})".format(self.data)

        return s

    def __str__(self):

        s = "{} -> ".format(self.__repr__())

        n = self.next

        while (n != None):
            s += "{} -> ".format(n.__repr__())
            n = n.next
        
        return s

class DLLNode:

    def __init__(self, data):
        self.data = data
        self.prev = self
        self.next = self

    def add(self, data):
        node = LLNode(data)

        node.prev = self.prev
        node.next = self

        self.prev.next = node
        self.prev = node

    def __repr__(self):

        s = "DLLNode({})".format(self.data)

        return s

    def __str__(self):

        n = self.next

        s = "{} -> ".format(self.__repr__())

        while (n != self):
            s += "{} -> ".format(n.__repr__())
            n = n.next
        
        s += "[{}]".format(self.__repr__())

        return s