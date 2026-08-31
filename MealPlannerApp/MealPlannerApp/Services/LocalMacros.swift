import Foundation

/// Mifflin–St Jeor macros so planning works without an API key.
enum LocalMacros {
    static func compute(profile: UserProfileEntity) -> MacroTargets {
        let kg = profile.weightLbs * 0.453592
        let cm = profile.heightInches * 2.54
        let age = Double(profile.age)
        let s: Double
        switch profile.sex {
        case .female: s = -161
        case .male, .other: s = 5
        }
        let bmr = (10 * kg) + (6.25 * cm) - (5 * age) + s
        let tdee = bmr * profile.activity.tdeeMultiplier
        let calories: Double
        switch profile.goal {
        case .muscleGain: calories = tdee + 250
        case .maintenance: calories = tdee
        case .fatLoss: calories = max(tdee - 400, bmr)
        }
        let proteinFloor = profile.weightLbs * (profile.goal == .fatLoss ? 1.0 : 1.0)
        let protein = max(proteinFloor, calories * 0.28 / 4)
        let fat = calories * 0.28 / 9
        let carbs = max(0, (calories - protein * 4 - fat * 9) / 4)
        let rationale: String
        switch profile.goal {
        case .muscleGain:
            rationale = "Local estimate: ~250 cal above maintenance, protein at ~1 g per lb."
        case .maintenance:
            rationale = "Local estimate: calories at maintenance, protein at ~1 g per lb."
        case .fatLoss:
            rationale = "Local estimate: modest deficit while keeping protein high."
        }
        return MacroTargets(
            bmr: bmr.rounded(),
            tdee: tdee.rounded(),
            targetCalories: calories.rounded(),
            targetProteinG: protein.rounded(),
            targetCarbsG: carbs.rounded(),
            targetFatG: fat.rounded(),
            rationale: rationale
        )
    }

    static func apply(_ macros: MacroTargets, to profile: UserProfileEntity) {
        profile.bmr = macros.bmr
        profile.tdee = macros.tdee
        profile.targetCalories = macros.targetCalories
        profile.targetProteinG = macros.targetProteinG
        profile.targetCarbsG = macros.targetCarbsG
        profile.targetFatG = macros.targetFatG
        profile.rationale = macros.rationale
        profile.updatedAt = .now
    }
}
