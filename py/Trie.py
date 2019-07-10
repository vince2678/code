from Tree import Tree

class Prefix_Tree:
    initiator = 0
    terminator = "*"

    def __init__(self):
        self.root = Tree(Prefix_Tree.initiator)

    def add_word(self, word):
        ''' Add word to Prefix tree
        '''
        add_word_helper(self.root, word)

    def find_prefix_match(self, prefix):
        ''' Tree, str -> list of str
            Return list of words matching prefix
        '''
        words = []

        for child in self.root.children:
            w = find_prefix_match_helper(child, prefix, "")
            words.extend(w)

        return words

    def __str__(self):
        w = self.find_prefix_match("")

        return w.__str__()

    def __repr__(self):
        return self.__str__()

def add_word_helper(tree, word):
    ''' Add word to prefix tree
    '''
    if len(word) == 0:
        c = Tree(Prefix_Tree.terminator)
        tree.children.append(c)
        return
    
    for child in tree.children:
        if child.data == word[0]:
            add_word_helper(child, word[1:])
            return
    
    c = Tree(word[0])
    add_word_helper(c, word[1:])
    tree.children.append(c)
        
def find_prefix_match_helper(tree, prefix, construct):
    ''' self, Tree, str -> list of str
    '''
    words = []

    if len(prefix) == 0:

        if tree.data == Prefix_Tree.terminator:
            words.append(construct)
        else:
            c = "{}{}".format(construct, tree.data)
            for child in tree.children:
                w = find_prefix_match_helper(child, prefix, c)
                words.extend(w)

        return words

    if prefix[0] != tree.data:
        return words

    c = "{}{}".format(construct, tree.data)
    for child in tree.children:
        w = find_prefix_match_helper(child, prefix[1:], c)
        words.extend(w)

    return words

