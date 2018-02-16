#!/usr/bin/env python


"""
Usage: testRelationships.py [host [port]]
Default host: localhost
Default port: 8080
"""


import httplib
import json
import sys
import time


class JSONClient:
	def __init__(self, host, port):
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
	def __init__(self, host, port):
		self.connection = JSONClient(host, port)
	
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


def main(args):
	host = "localhost"
	port = 8080
	if len(args) > 1:
		host = args[1]
		if len(args) > 2:
			port = int(args[2])
	c = EasyLoginClient(host, port)

	root_group_uuid = c.usergroups_create("root", "Root Group")
	node1_group_uuid = c.usergroups_create("node1", "Node 1 Group", memberOf = [root_group_uuid])
	node2_group_uuid = c.usergroups_create("node2", "Node 2 Group") #, memberOf = [root_group_uuid])
	node3_group_uuid = c.usergroups_create("node3", "Node 3 Group")
	c.usergroups_update(node2_group_uuid, memberOf = [root_group_uuid])
	root_group = c.usergroups_get(root_group_uuid)
	# c.usergroups_update(root_group_uuid, nestedGroups = [node1_group_uuid, node2_group_uuid, node3_group_uuid])
	c.usergroups_update(root_group_uuid, nestedGroups = root_group["nestedGroups"] + [node3_group_uuid])

	print("==== initial groups ====")
	print(c.usergroups_get(root_group_uuid))
	print(c.usergroups_get(node1_group_uuid))
	print(c.usergroups_get(node2_group_uuid))
	print(c.usergroups_get(node3_group_uuid))

	c.usergroups_delete(node2_group_uuid)

	print("==== after deleting node2 ====")
	print(c.usergroups_get(root_group_uuid))
	print(c.usergroups_get(node1_group_uuid))
	print(c.usergroups_get(node3_group_uuid))

	c.usergroups_delete(root_group_uuid)

	print("==== after deleting root ====")
	print(c.usergroups_get(node1_group_uuid))
	print(c.usergroups_get(node3_group_uuid))


if __name__ == '__main__':
    main(sys.argv)


