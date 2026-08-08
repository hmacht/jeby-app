//
//  OnboardingSteps.swift
//  Jeby
//
//  The three pages of the post-sign-up flow. Each is presentation only — the
//  view model owns the values and the saving.
//

import SwiftUI

/// Shared heading so the three steps read as one flow.
private struct StepHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title.weight(.bold))
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Step 1

struct NameStep: View {
    @Binding var name: String
    @Binding var bio: String
    @Binding var image: UIImage?

    var body: some View {
        VStack(spacing: 28) {
            StepHeader(
                title: "Who's sailing?",
                subtitle: "Your name and photo show up on the reports you post."
            )

            PhotoPickerButton(
                image: $image,
                icon: "person.crop.circle.badge.plus",
                prompt: "Add photo"
            )

            VStack(spacing: 14) {
                FormField(label: "Name", placeholder: "Skipper", value: $name)
                FormField(
                    label: "Bio",
                    placeholder: "Been running the Sound since '98",
                    value: $bio,
                    autocapitalization: .sentences
                )
            }
        }
    }
}

// MARK: - Step 2

struct BoatStep: View {
    @Binding var name: String
    @Binding var description: String
    @Binding var homeHarbor: String
    @Binding var length: String
    @Binding var weight: String
    @Binding var horsepower: String
    @Binding var maxPassengers: String
    @Binding var image: UIImage?

    var body: some View {
        VStack(spacing: 28) {
            StepHeader(
                title: "Your boat",
                subtitle: "Specs are optional — skip anything you don't know."
            )

            PhotoPickerButton(
                image: $image,
                icon: "sailboat.fill",
                prompt: "Add a photo of her",
                style: .card,
                size: 150
            )

            VStack(spacing: 14) {
                FormField(label: "Boat name", placeholder: "Jeby", value: $name)
                FormField(label: "Description", placeholder: "Grady White Freedom 215", value: $description)
                FormField(label: "Home harbor", placeholder: "Oak Bluffs, MA", value: $homeHarbor)

                HStack(spacing: 12) {
                    SpecFormField(label: "Length", placeholder: "21.5", unit: "ft", value: $length)
                    SpecFormField(label: "Weight", placeholder: "3,150", unit: "lb", value: $weight)
                }

                HStack(spacing: 12) {
                    SpecFormField(label: "Power", placeholder: "150", unit: "hp", value: $horsepower)
                    SpecFormField(label: "Passengers", placeholder: "8", unit: "", value: $maxPassengers, allowsDecimal: false)
                }
            }
        }
    }
}

// MARK: - Step 3

struct PetStep: View {
    @Binding var name: String
    @Binding var image: UIImage?

    var body: some View {
        VStack(spacing: 28) {
            StepHeader(
                title: "Your first mate",
                subtitle: "Every boat has one. Dogs, cats, and the occasional parrot."
            )

            PhotoPickerButton(
                image: $image,
                icon: "dog.fill",
                prompt: "Add photo"
            )

            FormField(label: "Name", placeholder: "Buoy", value: $name)
        }
    }
}
