#!/bin/bash

SERVER_URL="$1"

if [ -z "$SERVER_URL" ]
then
	echo "Please, specify server base URL as first argument"
	exit 1
fi

function createUserWithGivenNameSurnameFullNameShortnamePrincipalNameEmail {
	JSON_TEMPLATE="{ \"surname\": \"%SURNAME%\", \"email\": \"%EMAIL%\", \"fullName\": \"%FULLNAME%\", \"givenName\": \"%GIVENNAME%\", \"principalName\": \"%PRINCIPALNAME%\", \"shortname\": \"%SHORTNAME%\", \"authMethods\": { \"cleartext\": \"Password123\" }}"

	USER_RECORD=$(echo $JSON_TEMPLATE | sed "s/%GIVENNAME%/$1/g" | sed "s/%SURNAME%/$2/g" | sed "s/%FULLNAME%/$3/g" | sed "s/%SHORTNAME%/$4/g" | sed "s/%PRINCIPALNAME%/$5/g" | sed "s/%EMAIL%/$6/g")
	
	curl -k -s -X POST -H "Content-Type: application/json" -d "$USER_RECORD" "$SERVER_URL/db/users"
}


createUserWithGivenNameSurnameFullNameShortnamePrincipalNameEmail "Adriana" "Ocampo" "Adriana C. Ocampo Uria" "acou" "acou@am.storymaker.fr" "a.ocampo@storymaker.fr"
createUserWithGivenNameSurnameFullNameShortnamePrincipalNameEmail "Albert" "Einstein" "Albert Einstein" "ae" "ae@eu.storymaker.fr" "a.einstein@storymaker.fr"
createUserWithGivenNameSurnameFullNameShortnamePrincipalNameEmail "Anna" "Behrensmeyer" "Anna K. Behrensmeyer" "akb" "akb@am.storymaker.fr" "a.behrensmeyer@storymaker.fr"
createUserWithGivenNameSurnameFullNameShortnamePrincipalNameEmail "Blaise" "Pascal" "Blaise Pascal" "bp" "bp@eu.storymaker.fr" "b.pascal@storymaker.fr"
createUserWithGivenNameSurnameFullNameShortnamePrincipalNameEmail "Caroline" "Herschel" "Caroline Herschel" "ch" "ch@eu.storymaker.fr" "c.herschel@storymaker.fr"
createUserWithGivenNameSurnameFullNameShortnamePrincipalNameEmail "Cecilia" "Payne-Gaposchkin" "Cecilia Payne-Gaposchkin" "cpg" "cpg@eu.storymaker.fr" "c.payne@storymaker.fr"
createUserWithGivenNameSurnameFullNameShortnamePrincipalNameEmail "Chien-Shiung" "Wu" "Chien-Shiung Wu" "csw" "csw@ap.storymaker.fr" "c.wu@storymaker.fr"
createUserWithGivenNameSurnameFullNameShortnamePrincipalNameEmail "Dorothy" "Hodgkin" "Dorothy Hodgkin" "dh" "dh@eu.storymaker.fr" "d.hodgkin@storymaker.fr"
createUserWithGivenNameSurnameFullNameShortnamePrincipalNameEmail "Edmond" "Halley" "Edmond Halley" "eh" "eh@eu.storymaker.fr" "e.halley@sotrymaker.fr"
createUserWithGivenNameSurnameFullNameShortnamePrincipalNameEmail "Ewdin" "Hubble" "Edwin Powell Hubble" "eph" "eph@am.storymaker.fr" "e.hubble@sotrymaker.fr"
createUserWithGivenNameSurnameFullNameShortnamePrincipalNameEmail "Elizabeth" "Blackburn" "Elizabeth Blackburn" "eb" "eb@ap.storymaker.fr" "e.blackburn@sotrymaker.fr"
createUserWithGivenNameSurnameFullNameShortnamePrincipalNameEmail "Enrico" "Fermi" "Enrico Fermi" "ef" "ef@eu.storymaker.fr" "e.fermi@storymaker.fr"
createUserWithGivenNameSurnameFullNameShortnamePrincipalNameEmail "Erwin" "Schroedinger" "Erwin Schroedinger" "es" "es@eu.storymaker.fr" "e.schroedinger@storymaker.fr"
createUserWithGivenNameSurnameFullNameShortnamePrincipalNameEmail "Flossie" "Wong-Staal" "Flossie Wong-Staal" "fws" "fws@ap.storymaker.fr" "f.wong@storymaker.fr"
createUserWithGivenNameSurnameFullNameShortnamePrincipalNameEmail "Frieda" "Robscheit-Robbins" "Frieda Robscheit-Robbins" "frb" "frb@am.storymaker.fr" "f.robscheit@storymaker.fr"
createUserWithGivenNameSurnameFullNameShortnamePrincipalNameEmail "Geraldine" "Seydoux" "Geraldine Seydoux" "gs" "gs@am.storymaker.fr" "g.seydoux@storymaker.fr"
createUserWithGivenNameSurnameFullNameShortnamePrincipalNameEmail "Gertrude" "Elion" "Gertrude B. Elion" "gbe" "gbe@am.storymaker.fr" "g.elion@storymaker.fr"
createUserWithGivenNameSurnameFullNameShortnamePrincipalNameEmail "Ingrid" "Daubechies" "Ingrid Daubechies" "id" "id@eu.storymaker.fr" "i.daubechies@storymaker.fr"
createUserWithGivenNameSurnameFullNameShortnamePrincipalNameEmail "Jacqueline" "Barton" "Jacqueline K. Barton" "jkb" "jkb@am.storymaker.fr" "j.barton@storymaker.fr"
 
# Jane Goodall
# Jocelyn Bell Burnell
# Johannes Kepler
# Lene Vestergaard Hau
# Lise Meitner
# Lord Kelvin
# Maria Mitchell
# Marie Curie
# Max Born
# Max Planck
# Melissa Franklin
# Michael Faraday
# Mildred S. Dresselhaus
# Nicolaus Copernicus
# Niels Bohr
# Patricia S. Goldman-Rakic
# Patty Jo Watson
# Polly Matzinger
# Richard Phillips Feynman
# Rita Levi-Montalcini
# Rosalind Franklin
# Ruzena Bajcsy
# Sarah Boysen
# Shannon W. Lucid
# Shirley Ann Jackson
# Sir Ernest Rutherford
# Sir Isaac Newton
# Stephen Hawking
# Werner Karl Heisenberg
# Wilhelm Conrad Roentgen
# Wolfgang Ernst Pauli

exit 0
