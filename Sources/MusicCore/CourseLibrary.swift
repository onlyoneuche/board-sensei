public enum CourseLibrary {
    public static let courses = [
        JazzCourseCatalog.course,
        HanonCourseCatalog.course,
    ]

    public static func course(id: String) -> PracticeCourse? {
        courses.first { $0.id == id }
    }

    public static func context(courseID: String, lessonID: String) -> CourseLessonContext? {
        guard
            let course = course(id: courseID),
            let lesson = course.lesson(id: lessonID),
            let navigation = course.navigation(forLessonID: lessonID)
        else { return nil }

        return CourseLessonContext(
            courseID: course.id,
            courseTitle: course.title,
            experience: course.experience,
            lesson: lesson,
            navigation: navigation
        )
    }
}
