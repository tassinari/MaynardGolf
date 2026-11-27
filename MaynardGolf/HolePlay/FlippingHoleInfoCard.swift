import MaynardUI
import SwiftUI

/// A two-sided hole card turning top-to-bottom with the map’s interpolated progress (HP-HOLE-03,
/// HM-TR-04, #238). Animating progress here keeps the face change edge-on during settling as well as dragging.
@Animatable
struct FlippingHoleInfoCard: View {
    let current: RoundHole
    let target: RoundHole?
    let tee: Tee
    var progress: Double

    var body: some View {
        let fraction = target == nil ? 0 : progress
        let number = MapSwipe.displayedHole(current: current.number, target: target?.number, progress: fraction)
        let hole = number == target?.number ? (target ?? current) : current
        HoleInfoCard(number: hole.number, par: hole.par, yards: hole.source.yards(from: tee), handicap: hole.handicap)
            // Keep the system glass backdrop inside the face while it turns in 3D.
            .clipShape(.rect(cornerRadius: DSRadius.holeCard))
            .compositingGroup()
            // Orthographic projection keeps horizontal positions fixed throughout the turn.
            .rotation3DEffect(.degrees(MapSwipe.cardRotation(progress: fraction)), axis: (x: 1, y: 0, z: 0), anchor: .center, perspective: 0)
    }
}

#if DEBUG
#Preview("Flip stages") {
    if let course = try? BundleCourseProvider().course(id: AppDependencies.courseID) {
        let holes = RoundHoleBuilder.holes(course: course, holeCount: .nine)
        VStack(spacing: DSSpacing.l) {
            ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { progress in
                FlippingHoleInfoCard(current: holes[0], target: holes[1], tee: .blue, progress: progress)
            }
        }.padding().background(Color.ds.imageryBackdrop)
    }
}
#Preview("Turning, Dark") {
    if let course = try? BundleCourseProvider().course(id: AppDependencies.courseID) {
        let holes = RoundHoleBuilder.holes(course: course, holeCount: .nine)
        FlippingHoleInfoCard(current: holes[1], target: holes[0], tee: .blue, progress: 0.75)
            .padding().background(Color.ds.imageryBackdrop).preferredColorScheme(.dark)
    }
}
#endif
