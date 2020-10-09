# nodeobjects.py
# This file holds our data structures used when parsing the data files.

class CommonObject:
    id = None
    precedent = None
    precedent_id = None
    parent = None
    parent_id = None

    def set_precedent(self, object):
        self.precedent = object

    @property
    def depth(self):
        """ Retrieve the depth of this object based upon the travel length of the precedents """
        
        return self.get_depth(self.precedent)

    def get_depth(self, current_precedent=None, current_depth = 0):
        if current_precedent:
            resulting_depth = self.get_depth(current_precedent.precedent, current_depth + 1)
        else:
            resulting_depth = current_depth

        return resulting_depth

class Word(CommonObject):
    payload = None
    def __init__(self, parent_id, id, payload, precedent_id):
        self.id = id
        self.parent_id = parent_id
        self.payload = payload
        self.precedent_id = precedent_id

    @property
    def translated_payload(self):
        """ Translate our payload from the hex encoded payload. """

        translated_payload = self.payload.encode('utf-8').decode('unicode_escape').encode('utf-8')
        return translated_payload.decode('utf-8')

    def get_payload(self):
        return {
            "precedent": self.precedent_id,
            "id": self.id, 
            "parent_id": self.parent_id, 
            "payload": self.payload,
            "payload_translated":self.translated_payload,
            "type": "word",
        }

class Sentence(CommonObject):
    def __init__(self, id, precedent_id):
        self.id = id
        self.precedent_id = precedent_id
        self.words = [] # INSTANCE variable, if not list/object, is actually a shared class reference...

    def find_word(self, id):
        for word in self.words:
            if word.id == id:
                return word
        return None

    def add_word(self, word):
        if not isinstance(word, Word):
            raise ValueError("Must add instance of class Word()")

        if word in self.words:
            return

        if word.parent_id == self.id:
            word.parent = self
            self.words.append(word)

    def get_all_words(self):
        return self.words

    def map_precedents_and_order(self):
        """ Grab Word precedents and order them by their depth """

        for word in self.words:
            for precedent_word in self.words:
                if precedent_word.precedent_id == word.id:
                    precedent_word.set_precedent(word)

        self.words = sorted(self.words, key=lambda x: x.depth, reverse=False)

    @property
    def translated_payload(self):
        """ Create a sentence from the words array """

        translated_words = []
        for word in self.words:
            translated_words.append(word.translated_payload)
        return ' '.join(translated_words)

    def get_payload(self):
        children_payloads = []
        for word in self.words:
            children_payloads.append(word.get_payload())
        return {
            "precedent": self.precedent_id,
            "id": self.id,
            "parent_id": self.parent_id, 
            "type": "sentence", 
            "children" : children_payloads
            }

class Paragraph:
    def __init__(self):
        self.sentences = []
        
    def map_precedents_and_order(self):
        """ Grab sentence precedents and order them by their depth """

        for sentence in self.sentences:
            for precedent_sentence in self.sentences:
                if precedent_sentence.precedent_id == sentence.id:
                    precedent_sentence.set_precedent(sentence)

        self.sentences = sorted(self.sentences, key=lambda x: x.depth, reverse=False)

    def formulate_from_sentences(self):
        """ Compile all of our sentences into this paragraph """

        translated_paragraph = []
        for sentence in self.sentences:
            translated_paragraph.append(sentence.translated_payload)
        return ' '.join(translated_paragraph)

    def get_formatted_payload(self):
        formatted_payload = []
        for sentence in self.sentences:
            formatted_payload.append(sentence.get_payload())

        return {
            "resulting_paragraph" : self.formulate_from_sentences(),
            "sentences" : formatted_payload
        }