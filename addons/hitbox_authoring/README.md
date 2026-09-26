# Hitbox Authoring

Select an `AnimationPlayer`, choose an animation, and move the playhead to the frame where the hitbox should begin. Press **Add Hitbox** in the 2D toolbar or the Hitboxes bottom panel.

The plugin creates a `HitboxSpawner2D` beside the `AnimationPlayer` when one is not already present. Each entry stores its animation, start time, duration, transform, shape, and `HitData`.

The selected `Hitbox Preview` is temporary. Move, rotate, or scale the Area2D in the viewport and edit its `Shape` child in the Inspector. Moving outside the entry's duration or leaving the animation context removes the preview. The stored `HitboxFrameData` remains in the spawner and recreates a `HitboxComponent2D` during playback.
