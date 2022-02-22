GDC's terminology 
=============

The GDC has recorded its (presumably) active terminology in two files: `_term.yaml` and `_term_enum.yaml`, at https://github.com/NCI-GDC/gdcdictionary/tree/develop/gdcdictionary/schemas. These account for 6245 different entries. 

Most of these entries are associated with either the NCI Thesaurus or the caDSR as term origins or authorities. Each such entry includes an origin identifier: the NCIt concept code, or the caDSR CDE ID. Exceptions are:

7 terms with either "caBIG" or "FastQC" as origins.
205 terms with no origin specified. These could be considered terms with GDC as origin, but the terms themselves suggest they come from external authorities (perhaps via submitters).
"
There are a number of terms which share origin ids (that is, concepts) with other terms.
587 concepts are represented by 2 terms each, 225 concepts by 3 terms each, and so on to two single concepts represented by  10 and 11 terms, respectively.

These groups of terms, based on their English "values", are synonymous in many cases. In some cases, the terms indicate there are significant differences in meaning between the terms referencing the origin identifier. E.g.

    C9150: ["botryoid_sarcoma","sarcoma_botryoides"] # synonymous

vs.

	C4037: ["acute_myeloid_leukemia_with_prior_myelodysplastic_syndrome",
		    "acute_myeloid_leukemia_without_prior_myelodysplastic_syndrome"] # non-synonymous

## ICD-O-3 Codes

These are problematic in the GDC terms files. The code values themselves are represented as 5 digits with no slash separating the last digit from the first four. For example, the code for "Myeloid/Lymphoid Neoplasms with PDGFRB Rearrangement" (NCIt C84276), is 9966/3, but is given in the terms yaml as simply 99663. There is evidently an undocumented convention that is probably hard-coded in the GDC data management software that strips or adds the slash as required. 

A different approach is to precisely store ICD-O-3 (and other such non-human-readable, yet standard) codes in the MDB or in MDF, according to their _documented_ conventions. The format of MDF/MDB _handles_ is that of human-readable (English), snake-case identifiers without capitals. The _value_ field of a Term specification (or object) may contain any text.

It is convenient if term handles are unique, and they must be in the context of a single MDF file. However, the handles are not the term values, and uniqueness of Term objects in the MDB is provided by the nanoid for that object, not necessarily any piece of data within the object. Finally, synonymy of terms is encoded in the MDB, not by string or code matching, but by Term objects being linked to the same Concept object.

For ICD-O-3 codes, these may be represented as terms whose value is the precise code string, and whose origin/authority is ICD-O-3 itself. Another term whose value is "Myeloid/Lymphoid Neoplasms with PDGFRB Rearrangement" would have origin NCIt and origin code "C84276". Both of these terms would link to a single Concept object whose sole purpose is to indicate that the two terms are synonymous.


    match (o:origin {name:"ICD-O-3"}) with o
    match (t:term) where t.value =~ "[0-9]{5}" 
	with o, t, left(t.value,4)+"/"+right(t.value,1) as val
    merge (o)<-[:has_origin]-(s:term {value:val, origin_id:val, nanoid:t.nanoid})
		-[:has_concept]->(c:concept {ncit:t.origin_id})

	# remove the original term nodes
	match (t:term) where t.value =~ "[0-9]{5}"  detach delete t;

	# connect the NCIt terms to the new concept nodes
	match (c:concept) where exists(c.ncit) with c
	match (t:term) where t.origin_id = c.ncit
	merge (c)<-[:has_concept]-(t)

### Terms vs Term Handles in GDC

The GDC conflates what the Bento metamodel separately considers "handles" and "values" for Terms. In the MDB, Terms are not generally provided with handles, which have a practical use in the MDF format. 

To precisely represent the strings which actually constistute the data in GDC, MDB Term objects with values set to the GDC snake_case handles should be created, and linked to an Origin node representing the GDC. To relate these GDC terms to the NCIt synonyms, the terms should link to Concept objects that include the NCIt terms in their connections.

Values for NCIt terms from GDC, on the other hand, should in fact be the NCIt preferred term for the concept code,.

(When instantiating the model in the MDB, the term handles appear in enum lists. Create GDC Term objects using these, and link these terms to concept objects that connect to the NCI/caDSR/ICD-O-3 term objects.)

Create Concept nodes for remaining NCIt terms and the caDSR terms

    match (:origin {name:"NCIt"})<--(t:term) where not (t)-->(:concept)
	with t
	merge (t)-[:has_concept]->(c:concept {ncit:t.origin_id})

	match (:origin {name:"caDSR"})<--(t:term)
	with t
	merge (t)-[:has_concept]->(c:concept {cde:t.origin_id})

The ncit and cde properties are for convenience in later term linking.

Provide nanoids in batch by collecting neo4j ids of nodes missing them, and iterating on a simple update query

	import neo4j 
	from neo4j import GraphDatabase
	from bento_meta.mdb import make_nanoid
	drv = GraphDatabase("bolt://...",auth=(user,pass))
    with drv.session(default_access_mode=neo4j.WRITE_ACCESS) as s:
        result = s.run("match (c:concept) where not exists(c.nanoid) with c limit 1 set c.nanoid=$nanoid return c", {"nanoid":make_nanoid()})
    ...     while (result.peek()):
    ...         result = s.run("match (c:concept) where not exists(c.nanoid) with c limit 1 set c.nanoid=$nanoid return c", {"nanoid":make_nanoid()})

Term entities generated from enumerated value lists will have redundancies (the term with value "Yes" is represented many times across a number of properties). The MDF reader does not deduplicate these. 

`dedup-terms.py` performs the following:

Want to deduplicate terms with like values within models. Connect the one remaining term to the value sets from which the like terms are removed.

	match (t:term {_commit:$commit})<-[:has_term]-(v:value_set) 
    where not t.value =~ '^Stage.*' and not t.value =~ '[0-9]+' 
    with t.value as value, {term:t.nanoid,vs:v.nanoid} as pair 
    with value, head(collect(pair)) as th, 
		tail(collect(pair)) as pairs, count(value) as ct 
    where ct > 1
    with value, ct, th['term'] as thid, 
		[x in pairs where x['term'] <> th['term']] as pairs 
    return value, thid, pairs, ct 

Need to return the nanoids (scalars) and not the nodes themselves - nodes can't be used
in query parameters. 

(Don't deduplicate disease stage terms, or terms whose values are integers.)

For each row above:

- connect the valuesets to the single (first) term

        with $pairs as pairs, $thid as thid 
        unwind pairs as pair 
        with thid, pair['vs'] as vsid 
        match (t {nanoid:thid}),(vs {nanoid:vsid})
        merge (t)<-[:has_term]-(vs) 

- remove the redundant terms

		with $pairs as pairs 
        unwind pairs as pair 
        with pair['term'] as tid 
        match (t {nanoid:tid}) 
        detach delete t 

Terms from the individual models need to be connected to concepts that link with the external
standard terms (NCIt and caDSR)


Fulltext indices on term values and definitions:

    call db.index.fulltext.createNodeIndex("termValue",["term"],["value"])
    call db.index.fulltext.createNodeIndex("termValueDefn",["term"],["value","origin_definition"])
    call db.index.fulltext.createNodeIndex("termDefn",["term"],["origin_definition"])


Using n10s (neo4j semantics) on NCI Thesaurus - find the ICD-O-3 definitions for the codes, and their mapped NCIt concepts:

    match (a:owl__Class {rdfs__label:"Mapped ICDO3.1 Topography PT Terminology"})<-[:ncit__A8]-(b)
    with b
    match (b)<-[os:owl__annotatedSource]-(a:owl__Axiom)-[op:owl__annotatedProperty]->
          (p:owl__AnnotationProperty {rdfs__label:"Maps_To"})
    where a.ncit__P396 = "ICDO3"
    return b.ncit__NHC0 as concept, b.rdfs__label as ncit_pt, a.owl__annotatedTarget as icdo3_pt,
           a.ncit__P395 as icdo3_code, a.ncit__P397 as icdo3_ver;

Use the output of this query `icdo3.m.1.csv` in `icdo3.py` to add
`icdo3_ver` and `icdo_pt` to ICD-O-3 Terms (as `t.origin_version` and
`t.origin_definition`). Also create :represents link between term and
concept objects (according to c.ncit <- concept code mapped per NCIt
`concept`)

Now, a set of GDC terms coming from enumerated value sets have values
drawn directly from the ICD-O-3 origin definitions. We can link these
GDC term objects to the correct concept objects as follows:

    match (:origin {name:"ICD-O-3"})<--(t:term)
    with t 
    match (:origin {name:"GDC"})<--(s:term) 
    where s.value = t.origin_definition 
    with t, s
    match (c:concept)<-[:represents]-(t) 
    merge (c)<-[:represents]-(s);



### Fix YAML

Had to quote all lone instances of "True", "False", "Yes", "No", "yes", "no", to inhibit YAML parser interpretation as boolean values. This could be fixed in slurp.pl

Had to escape many single quotes where functioning as apostrophes. Fix in slurp.pl.




