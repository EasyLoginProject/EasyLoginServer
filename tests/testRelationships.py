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

from inspect import currentframe, getframeinfo


class Tester:
	def __init__(self, report_success = True):
		self.report_success = report_success
	
	def verify(self, statement, message):
		if self.report_success or not statement:
			frameinfo = getframeinfo(currentframe().f_back)
			if statement:
				tag = "SUCCESS"
			else:
				tag = "FAILURE"
			print ("[%s] Line %d: %s" % (tag, frameinfo.lineno, message))


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


def main(args):
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
	
	t = Tester()
	
	initial_group_count = len(c.usergroups_list()["usergroups"])

	root_group_uuid = c.usergroups_create("root", "Root Group")
	node1_group_uuid = c.usergroups_create("node1", "Node 1 Group", memberOf = [root_group_uuid])
	node2_group_uuid = c.usergroups_create("node2", "Node 2 Group") #, memberOf = [root_group_uuid])
	node3_group_uuid = c.usergroups_create("node3", "Node 3 Group")
	c.usergroups_update(node2_group_uuid, memberOf = [root_group_uuid])
	root_group = c.usergroups_get(root_group_uuid)
	# c.usergroups_update(root_group_uuid, nestedGroups = [node1_group_uuid, node2_group_uuid, node3_group_uuid])
	c.usergroups_update(root_group_uuid, nestedGroups = root_group["nestedGroups"] + [node3_group_uuid])
	
	t.verify(len(c.usergroups_list()["usergroups"]) == 4 + initial_group_count, "Initial group list contains 4 new elements.")
	t.verify(len(c.usergroups_get(root_group_uuid)["nestedGroups"]) == 3, "Root group contains 3 nested groups.")
	t.verify(len(c.usergroups_get(root_group_uuid)["memberOf"]) == 0, "Root group is member of no group.")
	t.verify(c.usergroups_get(node1_group_uuid)["memberOf"] == [root_group_uuid], "Node1 group is member of root group.")
	t.verify(c.usergroups_get(node2_group_uuid)["memberOf"] == [root_group_uuid], "Node2 group is member of root group.")
	t.verify(c.usergroups_get(node3_group_uuid)["memberOf"] == [root_group_uuid], "Node3 group is member of root group.")

# 	print("==== initial groups ====")
# 	print(c.usergroups_get(root_group_uuid))
# 	print(c.usergroups_get(node1_group_uuid))
# 	print(c.usergroups_get(node2_group_uuid))
# 	print(c.usergroups_get(node3_group_uuid))

	c.usergroups_delete(node2_group_uuid)
	t.verify(len(c.usergroups_list()["usergroups"]) == 3 + initial_group_count, "After deleting Node2 group: group list contains 3 elements.")

# 	print("==== after deleting node2 ====")
# 	print(c.usergroups_get(root_group_uuid))
# 	print(c.usergroups_get(node1_group_uuid))
# 	print(c.usergroups_get(node3_group_uuid))
	
	c.usergroups_delete(root_group_uuid)
	t.verify(len(c.usergroups_list()["usergroups"]) == 2 + initial_group_count, "After deleting root group: group list contains 2 elements.")
	t.verify(len(c.usergroups_get(node1_group_uuid)["memberOf"]) == 0, "Node1 group is member of no group.")
	t.verify(len(c.usergroups_get(node3_group_uuid)["memberOf"]) == 0, "Node3 group is member of no group.")

# 	print("==== after deleting root ====")
# 	print(c.usergroups_get(node1_group_uuid))
# 	print(c.usergroups_get(node3_group_uuid))


if __name__ == '__main__':
    main(sys.argv)


