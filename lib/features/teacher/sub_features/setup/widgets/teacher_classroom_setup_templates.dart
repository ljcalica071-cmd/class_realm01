class SubjectTemplate {
  final String category;
  final String cluster;
  final String name;
  final int ww;
  final int pt;
  final int ex;
  final int termsTaught;
  final String termBlock;
  final double st1Weight;
  final double st2Weight;
  final double teWeight;

  const SubjectTemplate({
    required this.category,
    this.cluster = '',
    required this.name,
    required this.ww,
    required this.pt,
    required this.ex,
    this.termsTaught = 1,
    this.termBlock = '1ST',
    this.st1Weight = 30,
    this.st2Weight = 30,
    this.teWeight = 40,
  });
}

const List<SubjectTemplate> defaultSubjectTemplates = [
  // SSHS - CORE (3 Terms)
  SubjectTemplate(category: 'SSHS - CORE', cluster: 'CORE', name: 'Effective Communication', ww: 20, pt: 50, ex: 30, termsTaught: 3, termBlock: '1ST, 2ND, 3RD'),
  SubjectTemplate(category: 'SSHS - CORE', cluster: 'CORE', name: 'General Mathematics', ww: 20, pt: 50, ex: 30, termsTaught: 3, termBlock: '1ST, 2ND, 3RD'),
  SubjectTemplate(category: 'SSHS - CORE', cluster: 'CORE', name: 'General Science', ww: 20, pt: 50, ex: 30, termsTaught: 3, termBlock: '1ST, 2ND, 3RD'),
  SubjectTemplate(category: 'SSHS - CORE', cluster: 'CORE', name: 'Life and Career Skills', ww: 20, pt: 50, ex: 30, termsTaught: 3, termBlock: '1ST, 2ND, 3RD'),
  SubjectTemplate(category: 'SSHS - CORE', cluster: 'CORE', name: 'Mabisang Komunikasyon', ww: 20, pt: 50, ex: 30, termsTaught: 3, termBlock: '1ST, 2ND, 3RD'),
  SubjectTemplate(category: 'SSHS - CORE', cluster: 'CORE', name: 'Pag-aaral ng Kasaysayan at Lipunang Pilipino', ww: 20, pt: 50, ex: 30, termsTaught: 3, termBlock: '1ST, 2ND, 3RD'),

  // ACADEMIC ELECTIVES
  SubjectTemplate(category: 'ACADEMIC ELECTIVES', cluster: 'ACADEMIC', name: 'Academic Elective 1', ww: 20, pt: 50, ex: 30, termsTaught: 1),
  SubjectTemplate(category: 'ACADEMIC ELECTIVES', cluster: 'ACADEMIC', name: 'Academic Elective 2', ww: 20, pt: 50, ex: 30, termsTaught: 1),

  // TECH-PRO ELECTIVES
  SubjectTemplate(category: 'TECH-PRO ELECTIVES', cluster: 'ICT', name: 'Computer Programming (Oracle Database)', ww: 15, pt: 65, ex: 20, termsTaught: 1),
  SubjectTemplate(category: 'TECH-PRO ELECTIVES', cluster: 'HOME ECONOMICS', name: 'Aesthetic Services (Beauty Care)', ww: 15, pt: 65, ex: 20, termsTaught: 1),
  SubjectTemplate(category: 'TECH-PRO ELECTIVES', cluster: 'TECH-PRO', name: 'Other Tech-Pro Elective', ww: 15, pt: 65, ex: 20, termsTaught: 1),

  // ARTS, SPORTS, HEALTH AND WELLNESS
  SubjectTemplate(category: 'ARTS, SPORTS, HEALTH AND WELLNESS', cluster: 'WELLNESS', name: 'First Aid', ww: 20, pt: 60, ex: 20, termsTaught: 1),
  SubjectTemplate(category: 'ARTS, SPORTS, HEALTH AND WELLNESS', cluster: 'ARTS', name: 'Art Criticism and Creative Markets', ww: 20, pt: 60, ex: 20, termsTaught: 1),

  // RESEARCH, DESIGN AND INNOVATION
  SubjectTemplate(category: 'RESEARCH, DESIGN AND INNOVATION', cluster: 'RESEARCH', name: 'Research Project', ww: 40, pt: 60, ex: 0, st1Weight: 50, st2Weight: 50, teWeight: 0, termsTaught: 1),

  // FIELD EXPERIENCE
  SubjectTemplate(category: 'FIELD EXPERIENCE', cluster: 'FIELD EXP', name: 'Field Experience', ww: 15, pt: 70, ex: 15, st1Weight: 0, st2Weight: 0, teWeight: 100, termsTaught: 1),

  // WORK IMMERSION
  SubjectTemplate(category: 'WORK IMMERSION', cluster: 'IMMERSION', name: 'Work Immersion', ww: 20, pt: 80, ex: 0, st1Weight: 50, st2Weight: 50, teWeight: 0, termsTaught: 1),
];
