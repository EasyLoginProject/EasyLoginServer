#!/usr/bin/env python


"""
Usage: testRelationships.py [host [port [ssl]]]
Default host: localhost
Default port: 8080
Default ssl: 0
"""


import httplib
import json
import sys
import time
import ssl
import unittest


class JSONClient:
	def __init__(self, host, port, use_ssl):
		if use_ssl:
			self.connection = httplib.HTTPSConnection(host, port, context=ssl._create_unverified_context())
		else:
			self.connection = httplib.HTTPConnection(host, port)
	
	def get(self, path):
		self.connection.request('GET', path)
		response = self.connection.getresponse()
		result = json.loads(response.read())
		return result
	
	def put(self, path, object):
		body = json.dumps(object)
		self.connection.request('PUT', path, body)
		response = self.connection.getresponse()
		result = json.loads(response.read())
		return result
	
	def post(self, path, object):
		body = json.dumps(object)
		self.connection.request('POST', path, body)
		response = self.connection.getresponse()
		result = json.loads(response.read())
		return result
	
	def delete(self, path):
		self.connection.request('DELETE', path)
		self.connection.getresponse().read()


class EasyLoginClient:
	def __init__(self, host, port, use_ssl):
		self.connection = JSONClient(host, port, use_ssl)
	
	def usergroups_generate_(self, shortname, commonName, email, memberOf, nestedGroups, members):
		object = {}
		if shortname:
			object["shortname"] = shortname
		if commonName:
			object["commonName"] = commonName
		if email:
			object["email"] = email
		if memberOf:
			object["memberOf"] = memberOf
		if nestedGroups:
			object["nestedGroups"] = nestedGroups
		if members:
			object["members"] = members
		return object
		
	def usergroups_list(self):
		result = self.connection.get("/db/usergroups")
		return result
	
	def usergroups_get(self, uuid):
		result = self.connection.get("/db/usergroups/%s" % uuid)
		return result
	
	def usergroups_create(self, shortname, commonName, email = None, memberOf = None, nestedGroups = None, members = None):
		object = self.usergroups_generate_(shortname, commonName, email, memberOf, nestedGroups, members)
		result = self.connection.post("/db/usergroups", object)
		return result["uuid"]
	
	def usergroups_update(self, uuid, shortname = None, commonName = None, email = None, memberOf = None, nestedGroups = None, members = None):
		object = self.usergroups_generate_(shortname, commonName, email, memberOf, nestedGroups, members)
		result = self.connection.put("/db/usergroups/%s" % uuid, object)
		return result
	
	def usergroups_delete(self, uuid):
		result = self.connection.delete("/db/usergroups/%s" % uuid)
		return result


class EasyLoginTestCase(unittest.TestCase):
	def failUnlessArraysContainSameElements(self, array1, array2, msg=None):
		if set(array1) != set(array2):
			raise self.failureException, (msg or "Arrays don't match")
	
	assertArraysContainSameElements = failUnlessArraysContainSameElements


class TestEasyLoginDatabaseAPI(EasyLoginTestCase):
	global c
	
	def setUp(self):
		self.initial_group_count = len(c.usergroups_list()["usergroups"])
	
	def test_usergroups(self):
	
		# create usergroups
		root_group_uuid = c.usergroups_create("root", "Root Group")
		node1_group_uuid = c.usergroups_create("node1", "Node 1 Group", memberOf = [root_group_uuid])
		node2_group_uuid = c.usergroups_create("node2", "Node 2 Group")
		node3_group_uuid = c.usergroups_create("node3", "Node 3 Group")
		c.usergroups_update(node2_group_uuid, memberOf = [root_group_uuid])
		self.assertEqual(len(c.usergroups_list()["usergroups"]), self.initial_group_count + 4)
		self.assertArraysContainSameElements(c.usergroups_get(root_group_uuid)["nestedGroups"], [node1_group_uuid, node2_group_uuid])
		
		# add membership
		root_group = c.usergroups_get(root_group_uuid)
		c.usergroups_update(root_group_uuid, nestedGroups = root_group["nestedGroups"] + [node3_group_uuid])
		self.assertEqual(len(c.usergroups_list()["usergroups"]), self.initial_group_count + 4)
		self.assertArraysContainSameElements(c.usergroups_get(root_group_uuid)["nestedGroups"], [node1_group_uuid, node2_group_uuid, node3_group_uuid])
		
		# verify memberships
		self.assertArraysContainSameElements(c.usergroups_get(root_group_uuid)["memberOf"], [], "Root group should be member of no group")
		self.assertArraysContainSameElements(c.usergroups_get(node1_group_uuid)["memberOf"], [root_group_uuid], "Node1 group should be member of root group")
		self.assertArraysContainSameElements(c.usergroups_get(node2_group_uuid)["memberOf"], [root_group_uuid], "Node2 group should be member of root group")
		self.assertArraysContainSameElements(c.usergroups_get(node3_group_uuid)["memberOf"], [root_group_uuid], "Node3 group should be member of root group")
		
		# delete node
		c.usergroups_delete(node2_group_uuid)
		self.assertEqual(len(c.usergroups_list()["usergroups"]), self.initial_group_count + 3)
		with self.assertRaises(ValueError):
			c.usergroups_get(node2_group_uuid)
		
		# delete root node
		c.usergroups_delete(root_group_uuid)
		self.assertEqual(len(c.usergroups_list()["usergroups"]), self.initial_group_count + 2)
		self.assertArraysContainSameElements(c.usergroups_get(node1_group_uuid)["memberOf"], [], "Node1 group should not be member of any group")
		self.assertArraysContainSameElements(c.usergroups_get(node3_group_uuid)["memberOf"], [], "Node3 group should not be member of any group")


def openEasyLoginConnection(args):
	host = "localhost"
	port = 8080
	use_ssl = False
	if len(args) > 1:
		host = args[1]
		if len(args) > 2:
			port = int(args[2])
			if len(args) > 3:
				use_ssl = int(args[3]) != 0
	c = EasyLoginClient(host, port, use_ssl)
	return c


if __name__ == '__main__':
	global c
	c = openEasyLoginConnection(sys.argv)
	unittest.main()


