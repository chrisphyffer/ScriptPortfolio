"""
Artwork Model sample
Christopher Phyffer 2020
https://phyffer.com

This is a simple code snippet from an Artwork organization project similar to ArtStation and Instagram
A basic model that abstracts a Database Table full of artwork (Could be Postgres, Mysql, etc)
"""

import random, 
import re
import json
import datetime

from sqlalchemy import func as sql_alchemy_func
from sqlalchemy.sql import expression
from dateutil import parser
from app import db, app

class Artwork(db.Model):

    __searchable__ = ['title', 'keywords']

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.ForeignKey(u'user.id'), nullable = False, index = True)
    artist = db.relationship(u'User', backref='artwork', order_by="desc(Artwork.id)")

    unique_hash = db.Column(db.String(app.config['ARTWORK_UID_LENGTH']), index = True, unique = True, nullable = False)

    title = db.Column(db.Text, nullable = False)
    body = db.Column(db.Text) # Rich Text Format
    keywords = db.Column(db.String(255))
    slug = db.Column(db.String(100), nullable = False )

    main_image = db.Column(db.String(255), nullable = False)
    gallery = db.Column(db.Text, default='[]')

    added = db.Column(db.DateTime(timezone = True), default = sql_alchemy_func.now())
    updated = db.Column(db.DateTime(timezone = True), onupdate = sql_alchemy_func.now() )

    coords = db.Column(db.String(255), nullable = False)

    model = db.Column(db.String(255), nullable=True, default = '' )
    model_type = db.Column(db.String(50), nullable = True) #sketchfab
    model_url = db.Column(db.String(255), nullable = True) #url

    sort_order = db.Column(db.Integer, nullable = True)

    category = db.Column(db.String(255), nullable = True)

    is_featured = db.Column(db.Boolean, nullable = True, default = False)

    hidden = db.Column(db.Boolean, server_default=expression.false(), nullable=False)

    def __init__(self, artist):
        self.artist = artist
        self.make_unique_hash()

    @property
    def uid(self):
        return self.unique_hash

    def make_unique_hash(self):
        self.unqiue_hash = ''
        existing = True
        while existing:
            self.unique_hash = ''.join(random.choice(string.hexdigits) for i in range(app.config['ARTWORK_UID_LENGTH']-1))
            existing_unique_hash = Artwork.query.filter(Artwork.unique_hash == self.unique_hash).first()
            if existing_unique_hash == None:
                existing = False
                break
            else:
                continue

        return self.unique_hash

    def set_title_and_slug(self, title):
        _punct_re = re.compile(r'[^a-zA-Z0-9\-\_]+')
        # Generates an ASCII-only slug.
        result = []
        for word in _punct_re.split(title.lower()):
            result.extend(word.split())
        self.slug = str(u'-'.join(result))
        self.title = title

    def set_keywords(self, keywords):
        keywords = keywords.replace(' ','')
        self.keywords = re.sub(r'[^a-zA-Z0-9,]','', keywords)

    def get_keywords(self):
        if self.keywords:
            return self.keywords.split(',')
        return []

    def get_keywords_to_edit(self):
        if self.keywords:
            return self.keywords.replace(',',', ')
        return ''

    def get_coords(self):
        return json.loads(self.coords)

    def set_coords(self, x, y, latest_x = 0, latest_y = 0):
        self.coords = json.dumps({'x':x,'y':y, "latest_x":latest_x, "latest_y":latest_y})

    def get_json(self, envelope_type = False):
        return {
            'artist':{
                'uid':self.artist.uid,
                'username':self.artist.username
            },
            'id':self.id,
            'uid':self.uid,
            'main_image':self.main_image,
            'added_utc_seconds':0, #TODO: Aware and Naive (self.added - datetime.datetime.utcfromtimestamp(0)).total_seconds(),
            'added' :self.added.strftime('%B %d, %Y'),
            'title':self.title,
            'body':self.body,
            'keywords':self.keywords,
            'unique_hash':self.unique_hash,
            'unique_id':self.unique_hash,
            'gallery':self.get_gallery(),
            'x':self.get_coords()['x'],
            'y':self.get_coords()['y'],
            'slug':self.slug,
            'latest_image':self.main_image,
            'latest_x':self.get_coords()['latest_x'] if 'latest_x' in self.get_coords() else 0,
            'latest_y':self.get_coords()['latest_y'] if 'latest_y' in self.get_coords() else 0,
            'model':self.model,
            'model_type':self.model_type,
            'model_url':self.model_url,
            'sort_order':self.sort_order,
            'category':self.category,
            'is_featured':self.is_featured
        }

    def set_gallery(self, gallery):
        if isinstance(gallery, list):
            self.gallery = json.dumps(gallery)


    def get_gallery(self):
        try:
            return json.loads(self.gallery)
        except Exception as e:
            return []