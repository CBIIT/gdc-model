match (a:owl__Class {rdfs__label:"Mapped ICDO3.1 Topography PT Terminology"})<-[:ncit__A8]-(b)
with b
match (b)<-[os:owl__annotatedSource]-(a:owl__Axiom)-[op:owl__annotatedProperty]->
      (p:owl__AnnotationProperty {rdfs__label:"Maps_To"})
where a.ncit__P396 = "ICDO3"
return b.ncit__NHC0 as concept, b.rdfs__label as ncit_pt, a.owl__annotatedTarget as icdo3_pt,
       a.ncit__P395 as icdo3_code, a.ncit__P397 as icdo3_ver;