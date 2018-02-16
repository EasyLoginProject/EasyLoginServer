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
	
	
	def user_generate_(self, givenName, surname, fullName, shortname, principalName, email):
		object = {}
		if givenName:
			object["givenName"] = givenName
		if surname:
			object["surname"] = surname
		if fullName:
			object["fullName"] = fullName
		if shortname:
			object["shortname"] = shortname
		if principalName:
			object["principalName"] = principalName
		if email:
			object["email"] = email
		return object
		
	def users_list(self):
		result = self.connection.get("/db/users")
		return result
	
	def user_get(self, uuid):
		result = self.connection.get("/db/users/%s" % uuid)
		return result
	
	def user_create(self, givenName, surname, fullName, shortname, principalName, email):
		object = self.user_generate_(givenName, surname, fullName, shortname, principalName, email)
		result = self.connection.post("/db/users", object)
		return result["uuid"]
	
	def user_update(self, uuid, givenName = None, surname = None, fullName = None, shortname = None, principalName = None, email = None):
		object = self.user_generate_(givenName, surname, fullName, shortname, principalName, email)
		result = self.connection.put("/db/users/%s" % uuid, object)
		return result
	
	def user_delete(self, uuid):
		result = self.connection.delete("/db/users/%s" % uuid)
		return result
	
	
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
	
	am_acou = c.user_create("Adriana", "Ocampo", "Adriana C. Ocampo Uria", "acou", "acou@am.storymaker.fr", "a.ocampo@storymaker.fr")
	am_akb = c.user_create("Anna", "Behrensmeyer", "Anna K. Behrensmeyer", "akb", "akb@am.storymaker.fr", "a.behrensmeyer@storymaker.fr")
	am_eph = c.user_create("Ewdin", "Hubble", "Edwin Powell Hubble", "eph", "eph@am.storymaker.fr", "e.hubble@sotrymaker.fr")
	am_frb = c.user_create("Frieda", "Robscheit-Robbins", "Frieda Robscheit-Robbins", "frb", "frb@am.storymaker.fr", "f.robscheit@storymaker.fr")
	am_gbe = c.user_create("Gertrude", "Elion", "Gertrude B. Elion", "gbe", "gbe@am.storymaker.fr", "g.elion@storymaker.fr")
	am_gs = c.user_create("Geraldine", "Seydoux", "Geraldine Seydoux", "gs", "gs@am.storymaker.fr", "g.seydoux@storymaker.fr")
	am_jkb = c.user_create("Jacqueline", "Barton", "Jacqueline K. Barton", "jkb", "jkb@am.storymaker.fr", "j.barton@storymaker.fr")
	ap_csw = c.user_create("Chien-Shiung", "Wu", "Chien-Shiung Wu", "csw", "csw@ap.storymaker.fr", "c.wu@storymaker.fr")
	ap_eb = c.user_create("Elizabeth", "Blackburn", "Elizabeth Blackburn", "eb", "eb@ap.storymaker.fr", "e.blackburn@sotrymaker.fr")
	ap_fws = c.user_create("Flossie", "Wong-Staal", "Flossie Wong-Staal", "fws", "fws@ap.storymaker.fr", "f.wong@storymaker.fr")
	eu_ae = c.user_create("Albert", "Einstein", "Albert Einstein", "ae", "ae@eu.storymaker.fr", "a.einstein@storymaker.fr")
	eu_bp = c.user_create("Blaise", "Pascal", "Blaise Pascal", "bp", "bp@eu.storymaker.fr", "b.pascal@storymaker.fr")
	eu_ch = c.user_create("Caroline", "Herschel", "Caroline Herschel", "ch", "ch@eu.storymaker.fr", "c.herschel@storymaker.fr")
	eu_cpg = c.user_create("Cecilia", "Payne-Gaposchkin", "Cecilia Payne-Gaposchkin", "cpg", "cpg@eu.storymaker.fr", "c.payne@storymaker.fr")
	eu_dh = c.user_create("Dorothy", "Hodgkin", "Dorothy Hodgkin", "dh", "dh@eu.storymaker.fr", "d.hodgkin@storymaker.fr")
	eu_ef = c.user_create("Enrico", "Fermi", "Enrico Fermi", "ef", "ef@eu.storymaker.fr", "e.fermi@storymaker.fr")
	eu_eh = c.user_create("Edmond", "Halley", "Edmond Halley", "eh", "eh@eu.storymaker.fr", "e.halley@sotrymaker.fr")
	eu_es = c.user_create("Erwin", "Schroedinger", "Erwin Schroedinger", "es", "es@eu.storymaker.fr", "e.schroedinger@storymaker.fr")
	eu_id = c.user_create("Ingrid", "Daubechies", "Ingrid Daubechies", "id", "id@eu.storymaker.fr", "i.daubechies@storymaker.fr")

	global_team = c.usergroups_create("all", "All of us", "all@storymaker.fr")
	eu_team = c.usergroups_create("eu", "Europe", "eu@storymaker.fr", memberOf = [global_team])
	ap_team = c.usergroups_create("ap", "Asia/Pasific", "ap@storymaker.fr")
	am_team = c.usergroups_create("am", "America", "am@storymaker.fr")

	c.usergroups_update(ap_team, memberOf = [global_team])
	
	global_team_object = c.usergroups_get(global_team)
	
	# c.usergroups_update(root_group_uuid, nestedGroups = [node1_group_uuid, node2_group_uuid, node3_group_uuid])
	c.usergroups_update(global_team, nestedGroups = global_team_object["nestedGroups"] + [am_team])

	c.usergroups_update(ap_team, memberOf = [ap_csw, ap_eb, ap_fws])
	c.usergroups_update(eu_team, memberOf = [eu_id, eu_es, eu_eh])
	c.usergroups_update(am_team, memberOf = [am_acou, am_akb, am_eph])

	print("==== initial groups ====")
	print(c.usergroups_get(global_team))
	print(c.usergroups_get(eu_team))
	print(c.usergroups_get(ap_team))
	print(c.usergroups_get(am_team))

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


