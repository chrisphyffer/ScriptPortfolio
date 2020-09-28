"""
Simple Unit Testing in Python for the Flask Framework.
Christopher Phyffer 2020
https://phyffer.com

This Unit Test will test the durability of a shopping cart's backend by posing as a client.
"""

#!flask/bin/python
import os
import unittest
import json

from app import app, db
from app.models.user import User
from app.models.game import Game

from app.tests.base_unittest import BaseUnitTest
from app.tests.utils import check_in_dict

class TestCartFunctionality(BaseUnitTest):
    """
    Cart Functionality Testing
    """

    user = { 'password':'test12345', 'verify_password':'test12345', 'email':'dev@phyffer.com' }

    def test_cart(self):
        #Create a few test games to purchase."
        self.create_sample_games()
        
        # Register as a user
        response = self.client.post('/user/register', headers=self.headers, data=json.dumps(self.user))
        response = json.loads(response.data.decode('utf-8'))
        print(response)
        self.assertIn('success', response)

        # Log In as the new user.
        pkg = {'username':self.user['email'], 'password':self.user['password']}
        response = self.client.post('/user/auth', headers=self.headers, data=json.dumps(pkg))
        response = json.loads(response.data.decode('utf-8'))
        self.assertIn('access_token', response)
        self.headers['Authorization'] = 'Bearer {}'.format(response['access_token'])
        print(response)
        
        # Check to see the user's library. Should be zero.
        response = self.client.get('/user/library', headers=self.headers)
        print(response)
        response = json.loads(response.data.decode('utf-8'))
        self.assertIn('success', response)
        self.assertEqual(response['library'], [])

        # Look in the list of games available for purchase
        response = self.client.get('/game/list', headers=self.headers)
        response = json.loads(response.data.decode('utf-8'))
        self.assertIn('success', response)
        self.assertGreater(len(response['games']), 0)
        game_to_purchase = response['games'][0]

        #1 Add a nonexistent game_id to your cart
        pkg = {'game_id':response['games'][0]}
        response = self.client.post('/store/cart/manage-product/add', headers=self.headers, data=json.dumps(pkg))
        response = json.loads(response.data.decode('utf-8'))
        self.assertIn('error', response)

        # add a non-string, non integer game_id to your cart.
        pkg = {'game_id':[]}
        response = self.client.post('/store/cart/manage-product/add', headers=self.headers, data=json.dumps(pkg))
        response = json.loads(response.data.decode('utf-8'))
        self.assertIn('error', response)

        # Attempt to add a hidden game into the cart.
        pkg = {'game_id':self.hidden_game['uid']}
        response = self.client.post('/store/cart/manage-product/add', headers=self.headers, data=json.dumps(pkg))
        response = json.loads(response.data.decode('utf-8'))
        self.assertIn('error', response)

        # Add this game to your cart. Verify it is in your cart.
        pkg = {'game_id':game_to_purchase['uid']}
        print(pkg)
        response = self.client.post('/store/cart/manage-product/add', headers=self.headers, data=json.dumps(pkg))
        print(response)
        response = json.loads(response.data.decode('utf-8'))
        self.assertIn('success', response)
        self.assertIn('items', response['cart'])
        self.assertIn(game_to_purchase['uid'], response['cart']['items'])
        self.assertEqual(len(response['cart']['items']), 1)
        print(response)

        # Add this game to your cart again. Nothing should happen.
        response = self.client.post('/store/cart/manage-product/add', headers=self.headers, data=json.dumps(pkg))
        response = json.loads(response.data.decode('utf-8'))
        self.assertIn('success', response)
        self.assertIn('items', response['cart'])
        self.assertIn(game_to_purchase['uid'], response['cart']['items'])
        self.assertEqual(len(response['cart']['items']), 1)
        print(response)

        # Remove this game from your cart. Verify that it is no longer in your cart
        response = self.client.post('/store/cart/manage-product/remove', headers=self.headers, data=json.dumps(pkg))
        print(response)
        response = json.loads(response.data.decode('utf-8'))
        self.assertIn('success', response)
        self.assertIn('items', response['cart'])
        self.assertEqual(len(response['cart']['items']), 0)

        # Add the game back in again
        response = self.client.post('/store/cart/manage-product/add', headers=self.headers, data=json.dumps(pkg))
        print(response)
        response = json.loads(response.data.decode('utf-8'))
        self.assertIn('success', response)
        self.assertIn('items', response['cart'])
        self.assertIn(game_to_purchase['uid'], response['cart']['items'])
        print(response)