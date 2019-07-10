class Tree:

    def __init__(self, data):
        ''' Initialise tree
        '''
        self.children = []
        self.data = data

    def add_child(self, data):
        ''' Tree, NoneType -> Tree
            Add child with data in Tree
            Return Tree with data
        '''
        for child in self.children:
            if child.data == data:
                return child
        
        c = Tree(data)
        self.children.append(c)

        return c

    def remove_child(self, data):
        ''' Remove child with data if in tree.
            Return True if successful, False otherwise
        '''
        for child in self.children:
            if child.data == data:
                self.children.remove(child)
                return True
        
        return False

    def print_tree(self, depth = 0, parent = None):
        ''' Print a representation of the tree 
        '''
        out = "{}{} -> {}\n".format(" "*depth, parent, self.__repr__())

        for child in self.children:
            out += child.print_tree(depth + 1, self.__repr__())

        return out

    def __str__(self):
        return self.print_tree()

    def __repr__(self):
        return "Tree({})".format(self.data)