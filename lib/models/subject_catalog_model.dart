/// DepEd Order No. 15, s. 2026 Subject Catalog & Preset Model
/// Strengthened Senior High School Curriculum
library;

class SubjectCatalogItem {
  final String id;
  final String category;
  final String cluster;
  final String name;
  final String gradeLevel; // 'Grade 11', 'Grade 12', or 'Both'
  final double wwWeight; // Written Works %
  final double ptWeight; // Performance Tasks %
  final double exWeight; // Quarterly Exam %
  final int termsTaught; // default 3

  const SubjectCatalogItem({
    required this.id,
    required this.category,
    required this.cluster,
    required this.name,
    this.gradeLevel = 'Both',
    required this.wwWeight,
    required this.ptWeight,
    required this.exWeight,
    this.termsTaught = 3,
  });
}

class DepEdSubjectCatalog {
  // Official Subject Categories under DO 15, s. 2026
  static const String catCore = 'SSHS - CORE';
  static const String catAcademic = 'SSHS - ACADEMIC';
  static const String catTechPro = 'SSHS - TECH-PRO';
  static const String catArtsSports = 'SSHS - ARTS & SPORTS';
  static const String catResearch = 'SSHS - RESEARCH, DESIGN, AND INNOVATION';
  static const String catImmersion = 'SSHS - WORK IMMERSION / APPRENTICESHIP';
  static const String catCustom = 'CUSTOM / OLD CURRICULUM';

  static const List<String> categories = [
    catCore,
    catAcademic,
    catTechPro,
    catArtsSports,
    catResearch,
    catImmersion,
    catCustom,
  ];

  /// Master list of subjects extracted from TEMPLATE-SSHS-E-Class-Record-SY-2026-2027.xlsx
  static const List<SubjectCatalogItem> allSubjects = [
    // --- SSHS - CORE (20% WW - 50% PT - 30% EX) ---
    SubjectCatalogItem(
      id: 'core_genmath',
      category: catCore,
      cluster: 'CORE',
      name: 'General Mathematics',
      gradeLevel: 'Grade 11',
      wwWeight: 20,
      ptWeight: 50,
      exWeight: 30,
    ),
    SubjectCatalogItem(
      id: 'core_effcomm',
      category: catCore,
      cluster: 'CORE',
      name: 'Effective Communication',
      gradeLevel: 'Grade 11',
      wwWeight: 20,
      ptWeight: 50,
      exWeight: 30,
    ),
    SubjectCatalogItem(
      id: 'core_statprob',
      category: catCore,
      cluster: 'CORE',
      name: 'Statistics and Probability',
      gradeLevel: 'Grade 11',
      wwWeight: 20,
      ptWeight: 50,
      exWeight: 30,
    ),
    SubjectCatalogItem(
      id: 'core_gensci',
      category: catCore,
      cluster: 'CORE',
      name: 'General Science',
      gradeLevel: 'Grade 11',
      wwWeight: 20,
      ptWeight: 50,
      exWeight: 30,
    ),
    SubjectCatalogItem(
      id: 'core_earthlife',
      category: catCore,
      cluster: 'CORE',
      name: 'Earth and Life Science',
      gradeLevel: 'Grade 11',
      wwWeight: 20,
      ptWeight: 50,
      exWeight: 30,
    ),
    SubjectCatalogItem(
      id: 'core_pehealth',
      category: catCore,
      cluster: 'CORE',
      name: 'Physical Education and Health',
      gradeLevel: 'Both',
      wwWeight: 20,
      ptWeight: 50,
      exWeight: 30,
    ),
    SubjectCatalogItem(
      id: 'core_rizal',
      category: catCore,
      cluster: 'CORE',
      name: 'Life and Works of Rizal',
      gradeLevel: 'Grade 12',
      wwWeight: 20,
      ptWeight: 50,
      exWeight: 30,
    ),

    // --- SSHS - ACADEMIC: ABM (20% WW - 50% PT - 30% EX) ---
    SubjectCatalogItem(
      id: 'acad_bizfinance',
      category: catAcademic,
      cluster: 'BUSINESS AND ENTREPRENEURSHIP',
      name: 'Business 2: Finance and Income Tax',
      gradeLevel: 'Grade 12',
      wwWeight: 20,
      ptWeight: 50,
      exWeight: 30,
    ),
    SubjectCatalogItem(
      id: 'acad_fabm1',
      category: catAcademic,
      cluster: 'BUSINESS AND ENTREPRENEURSHIP',
      name: 'Fundamentals of Accountancy, Business, and Management 1',
      gradeLevel: 'Grade 11',
      wwWeight: 20,
      ptWeight: 50,
      exWeight: 30,
    ),
    SubjectCatalogItem(
      id: 'acad_appmacro',
      category: catAcademic,
      cluster: 'BUSINESS AND ENTREPRENEURSHIP',
      name: 'Applied Economics',
      gradeLevel: 'Grade 12',
      wwWeight: 20,
      ptWeight: 50,
      exWeight: 30,
    ),

    // --- SSHS - ACADEMIC: STEM (20% WW - 50% PT - 30% EX) ---
    SubjectCatalogItem(
      id: 'acad_precalc',
      category: catAcademic,
      cluster: 'SCIENCE, TECHNOLOGY, ENGINEERING, AND MATHEMATICS',
      name: 'Pre-Calculus',
      gradeLevel: 'Grade 11',
      wwWeight: 20,
      ptWeight: 50,
      exWeight: 30,
    ),
    SubjectCatalogItem(
      id: 'acad_bascalc',
      category: catAcademic,
      cluster: 'SCIENCE, TECHNOLOGY, ENGINEERING, AND MATHEMATICS',
      name: 'Basic Calculus',
      gradeLevel: 'Grade 11',
      wwWeight: 20,
      ptWeight: 50,
      exWeight: 30,
    ),
    SubjectCatalogItem(
      id: 'acad_genphys1',
      category: catAcademic,
      cluster: 'SCIENCE, TECHNOLOGY, ENGINEERING, AND MATHEMATICS',
      name: 'General Physics 1',
      gradeLevel: 'Grade 12',
      wwWeight: 20,
      ptWeight: 50,
      exWeight: 30,
    ),

    // --- SSHS - ACADEMIC: HUMSS (20% WW - 50% PT - 30% EX) ---
    SubjectCatalogItem(
      id: 'acad_creatwrit',
      category: catAcademic,
      cluster: 'ARTS, SOCIAL SCIENCES, AND HUMANITIES',
      name: 'Creative Writing',
      gradeLevel: 'Grade 11',
      wwWeight: 20,
      ptWeight: 50,
      exWeight: 30,
    ),
    SubjectCatalogItem(
      id: 'acad_polgov',
      category: catAcademic,
      cluster: 'ARTS, SOCIAL SCIENCES, AND HUMANITIES',
      name: 'Philippine Politics and Governance',
      gradeLevel: 'Grade 12',
      wwWeight: 20,
      ptWeight: 50,
      exWeight: 30,
    ),

    // --- SSHS - TECH-PRO: ICT (15% WW - 65% PT - 20% EX) ---
    SubjectCatalogItem(
      id: 'tech_cp_java',
      category: catTechPro,
      cluster: 'INFORMATION AND COMMUNICATIONS TECHNOLOGY',
      name: 'Computer Programming (Java)',
      gradeLevel: 'Grade 11',
      wwWeight: 15,
      ptWeight: 65,
      exWeight: 20,
    ),
    SubjectCatalogItem(
      id: 'tech_cp_dotnet',
      category: catTechPro,
      cluster: 'INFORMATION AND COMMUNICATIONS TECHNOLOGY',
      name: 'Computer Programming (.Net Technology)',
      gradeLevel: 'Grade 11',
      wwWeight: 15,
      ptWeight: 65,
      exWeight: 20,
    ),
    SubjectCatalogItem(
      id: 'tech_css',
      category: catTechPro,
      cluster: 'INFORMATION AND COMMUNICATIONS TECHNOLOGY',
      name: 'Computer Systems Servicing (CSS)',
      gradeLevel: 'Grade 12',
      wwWeight: 15,
      ptWeight: 65,
      exWeight: 20,
    ),
    SubjectCatalogItem(
      id: 'tech_anim',
      category: catTechPro,
      cluster: 'INFORMATION AND COMMUNICATIONS TECHNOLOGY',
      name: '2D Animation & Illustration',
      gradeLevel: 'Grade 11',
      wwWeight: 15,
      ptWeight: 65,
      exWeight: 20,
    ),

    // --- SSHS - ARTS & SPORTS (20% WW - 60% PT - 20% EX) ---
    SubjectCatalogItem(
      id: 'arts_criticism',
      category: catArtsSports,
      cluster: 'ARTS AND DESIGN',
      name: 'Art Criticism and Creative Markets',
      gradeLevel: 'Grade 12',
      wwWeight: 20,
      ptWeight: 60,
      exWeight: 20,
    ),
    SubjectCatalogItem(
      id: 'sports_science',
      category: catArtsSports,
      cluster: 'SPORTS TRACK',
      name: 'Sports Officiating and Activity Management',
      gradeLevel: 'Grade 12',
      wwWeight: 20,
      ptWeight: 60,
      exWeight: 20,
    ),

    // --- SSHS - RESEARCH (15% WW - 70% PT - 15% EX) ---
    SubjectCatalogItem(
      id: 'res_capstone',
      category: catResearch,
      cluster: 'CAPSTONE PROJECTS',
      name: 'Capstone Project / Innovation in Daily Life',
      gradeLevel: 'Grade 12',
      wwWeight: 15,
      ptWeight: 70,
      exWeight: 15,
    ),
    SubjectCatalogItem(
      id: 'res_prac1',
      category: catResearch,
      cluster: 'CAPSTONE PROJECTS',
      name: 'Practical Research 1',
      gradeLevel: 'Grade 11',
      wwWeight: 15,
      ptWeight: 70,
      exWeight: 15,
    ),

    // --- SSHS - WORK IMMERSION (40% WW - 60% PT - 0% EX) ---
    SubjectCatalogItem(
      id: 'imm_field',
      category: catImmersion,
      cluster: 'WORK IMMERSION',
      name: 'Work Immersion / Field Exposure',
      gradeLevel: 'Grade 12',
      wwWeight: 40,
      ptWeight: 60,
      exWeight: 0,
    ),
  ];

  static List<String> getClusters(String category) {
    if (category == catCustom) return ['CUSTOM'];
    return allSubjects
        .where((s) => s.category == category)
        .map((s) => s.cluster)
        .toSet()
        .toList();
  }

  static List<SubjectCatalogItem> getSubjects({
    required String category,
    required String cluster,
    String? gradeLevel,
  }) {
    return allSubjects.where((s) {
      if (s.category != category) return false;
      if (cluster.isNotEmpty && s.cluster != cluster) return false;
      if (gradeLevel != null && gradeLevel != 'Both') {
        if (s.gradeLevel != 'Both' && s.gradeLevel != gradeLevel) return false;
      }
      return true;
    }).toList();
  }

  /// Get standard DO 15, s. 2026 weights for a given category
  static Map<String, double> getDefaultWeights(String category) {
    switch (category) {
      case catCore:
      case catAcademic:
        return {'ww': 20.0, 'pt': 50.0, 'ex': 30.0};
      case catTechPro:
        return {'ww': 15.0, 'pt': 65.0, 'ex': 20.0};
      case catArtsSports:
        return {'ww': 20.0, 'pt': 60.0, 'ex': 20.0};
      case catResearch:
        return {'ww': 15.0, 'pt': 70.0, 'ex': 15.0};
      case catImmersion:
        return {'ww': 40.0, 'pt': 60.0, 'ex': 0.0};
      default:
        return {'ww': 30.0, 'pt': 50.0, 'ex': 20.0};
    }
  }
}
