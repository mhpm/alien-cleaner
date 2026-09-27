# Godot MCP Pro — referencia de comandos

Generado desde `addons/godot_mcp/commands/*.gd`. `param*` = obligatorio; `param:tipo=default` = opcional; sin tipo = cualquier valor (string parseable por Godot, array u objeto).
Cada comando es una herramienta MCP `mcp__godot-mcp-pro__<comando>`.

## analysis

- `find_unused_resources`(path:string="res://", include_addons:bool=false)
- `analyze_signal_flow`()
- `analyze_scene_complexity`(path:string="")
- `find_script_references`(query*, path:string="res://", include_addons:bool=false)
- `detect_circular_dependencies`(path:string="res://", include_addons:bool=false)
- `get_project_statistics`(path:string="res://", include_addons:bool=false)

## android

- `list_android_devices`()
- `get_android_preset_info`(preset_name:string="", preset_index:int=-1)
- `deploy_to_android`(preset_name:string="", preset_index:int=-1, device_serial:string="", debug:bool=true, launch:bool=true, skip_export:bool=false)

## animation

- `list_animations`(node_path*)
- `create_animation`(node_path*, name*, length:float=1.0, loop_mode:int=0)
- `add_animation_track`(node_path*, animation*, track_path*, track_type:string="value", update_mode:string="")
- `set_animation_keyframe`(node_path*, animation*, track_index:int=0, time:float=0.0, easing:float=1.0, value)
- `get_animation_info`(node_path*, animation*)
- `remove_animation`(node_path*, name*)

## animation_tree

- `create_animation_tree`(node_path*, anim_player:string="", name:string="AnimationTree")
- `get_animation_tree_structure`(node_path*)
- `add_state_machine_state`(node_path*, state_name*, state_machine_path:string="", state_type:string="animation", position_x:float=0.0, position_y:float=0.0, animation:string="")
- `remove_state_machine_state`(node_path*, state_name*, state_machine_path:string="")
- `add_state_machine_transition`(node_path*, from_state*, to_state*, state_machine_path:string="", switch_mode:string="immediate", advance_mode:string="enabled", advance_expression:string="", xfade_time:float)
- `remove_state_machine_transition`(node_path*, from_state*, to_state*, state_machine_path:string="")
- `set_blend_tree_node`(node_path*, blend_tree_state*, bt_node_name*, bt_node_type*, state_machine_path:string="", position_x:float=0.0, position_y:float=0.0, animation:string="", connect_to:string="", connect_port:int=0)
- `set_tree_parameter`(node_path*, parameter*, value)

## audio

- `get_audio_bus_layout`()
- `add_audio_bus`(name*, at_position:int=-1, volume_db:float, send:string="", solo:bool, mute:bool)
- `set_audio_bus`(name*, volume_db:float, solo:bool, mute:bool, bypass_effects:bool, send:string="", rename)
- `add_audio_bus_effect`(bus*, effect_type*, at_position:int=-1, params, room_size, damping, wet, dry, spread, voice_count, tap1_active, tap1_delay_ms, tap1_level_db, tap2_active, tap2_delay_ms, tap2_level_db, threshold, ratio, attack_us, release_ms, gain, mix, ceiling_db, threshold_db, soft_clip_db, soft_clip_ratio, range_min_hz, range_max_hz, rate_hz, feedback, depth, mode, pre_gain, post_gain, keep_hf_hz, drive, cutoff_hz, resonance, volume_db)
- `add_audio_player`(node_path*, name*, type:string="AudioStreamPlayer", stream:string="", volume_db:float, bus:string="", autoplay:bool, max_distance:float, attenuation:float, attenuation_model:int, unit_size:float)
- `get_audio_info`(node_path*)

## batch

- `find_nodes_by_type`(type*, recursive:bool=true)
- `find_signal_connections`(signal_name:string="", node_path:string="")
- `batch_set_property`(type*, property*, value)
- `batch_add_nodes`(nodes)
- `find_node_references`(pattern*)
- `get_scene_dependencies`(path*)
- `cross_scene_set_property`(type*, property*, path_filter:string="res://", exclude_addons:bool=true, force:bool=false, dry_run:bool=not force, value)

## editor

- `get_editor_errors`(max_lines:int=50)
- `get_output_log`(max_lines:int=100, filter:string="")
- `get_editor_screenshot`(save_path)
- `get_game_screenshot`(save_path)
- `execute_editor_script`(code*, allow_unsafe_editor_io:bool=false)
- `clear_output`()
- `reload_plugin`()
- `reload_project`()
- `get_signals`(node_path*)
- `compare_screenshots`(image_a*, image_b*, threshold:int=10)
- `set_auto_dismiss`(enabled)
- `get_editor_camera`()
- `set_editor_camera`(fov:float, position, rotation_degrees, look_at)

## export

- `list_export_presets`()
- `export_project`(preset_index:int=-1, preset_name:string="", debug:bool=true)
- `get_export_info`()

## headless

- `run_headless_scene`(scene_path*, timeout_sec:float=_DEFAULT_TIMEOUT_SEC, quit_after_frames:int=0, args)
- `run_headless_script`(script_path*, timeout_sec:float=_DEFAULT_TIMEOUT_SEC, quit_after_frames:int=0, args)
- `get_godot_executable`()

## input

- `simulate_key`(keycode*, pressed:bool=true, shift:bool=false, ctrl:bool=false, alt:bool=false)
- `simulate_mouse_click`(button:int=1, pressed:bool=true, double_click:bool=false, auto_release:bool=true, x:float=0.0, y:float=0.0)
- `simulate_mouse_move`(x:float=0.0, y:float=0.0, relative_x:float=0.0, relative_y:float=0.0, button_mask:int=0, unhandled:bool=false)
- `simulate_action`(action*, pressed:bool=true, strength:float=1.0)
- `simulate_sequence`(frame_delay:int=1, events)

## input_map

- `get_input_actions`(filter:string="", include_builtin:bool=false)
- `set_input_action`(action*, deadzone:float=0.5, events)

## navigation

- `setup_navigation_region`(node_path*, mode:string="auto", name:string="NavigationRegion3D", agent_radius:float=0.5, agent_height:float=1.5, agent_max_climb:float=0.25, agent_max_slope:float=45.0, cell_size:float=0.25, cell_height:float=0.25, navigation_layers:int, source_geometry_mode)
- `bake_navigation_mesh`(node_path*, outline)
- `setup_navigation_agent`(node_path*, mode:string="auto", name:string="NavigationAgent3D" if is_3d else "NavigationAgent2D", path_desired_distance:float, target_desired_distance:float, radius:float, neighbor_distance:float, max_neighbors:int, max_speed:float, avoidance_enabled:bool, navigation_layers:int)
- `set_navigation_layers`(node_path*, layers:int, layer_bits, layer_names)
- `get_navigation_info`(node_path*)

## node

- `add_node`(type*, parent_path:string=".", name:string="", properties)
- `delete_node`(node_path*)
- `duplicate_node`(node_path*, name:string="")
- `move_node`(node_path*, new_parent_path*)
- `update_property`(node_path*, property*, value)
- `get_node_properties`(node_path*, category:string="")
- `add_resource`(node_path*, property*, resource_type*, resource_properties)
- `set_anchor_preset`(node_path*, preset*, keep_offsets:bool=false)
- `rename_node`(node_path*, new_name*)
- `connect_signal`(source_path*, signal_name*, target_path*, method_name*, deferred:bool=false, one_shot:bool=false)
- `disconnect_signal`(source_path*, signal_name*, target_path*, method_name*)
- `get_node_groups`(node_path*)
- `set_node_groups`(node_path*, groups)
- `find_nodes_in_group`(group*)
- `get_editor_selection`(top_only:bool=false)
- `select_nodes`(node_path*, mode:string="replace", inspect:bool=true, focus:bool=inspect, inspector_only:bool=false, for_property:string="", node_paths)
- `clear_editor_selection`()

## particle

- `create_particles`(parent_path*, name:string="Particles", is_3d:bool=false, amount:int=16, lifetime:float=1.0, one_shot:bool=false, explosiveness:float=0.0, randomness:float=0.0, emitting:bool=true)
- `set_particle_material`(node_path*, spread:float, initial_velocity_min:float, initial_velocity_max:float, scale_min:float, scale_max:float, emission_sphere_radius:float, emission_ring_radius:float, emission_ring_inner_radius:float, emission_ring_height:float, angular_velocity_min:float, angular_velocity_max:float, orbit_velocity_min:float, orbit_velocity_max:float, damping_min:float, damping_max:float, attractor_interaction_enabled:bool, direction, gravity, color, emission_shape, emission_box_extents)
- `set_particle_color_gradient`(node_path*, stops)
- `apply_particle_preset`(node_path*, preset*)
- `get_particle_info`(node_path*)

## physics

- `setup_collision`(node_path*, shape*, dimension:string="2d", width:float=32.0, height:float=32.0, radius:float=16.0, ax:float=0.0, ay:float=0.0, bx:float=32.0, by:float=0.0, disabled:bool=false, one_way_collision:bool=false, depth:float=1.0, points)
- `set_physics_layers`(node_path*, collision_layer, collision_mask)
- `get_physics_layers`(node_path*)
- `add_raycast`(node_path*, dimension:string="2d", name:string="RayCast", enabled:bool=true, collision_mask:int=1, collide_with_areas:bool=false, collide_with_bodies:bool=true, hit_from_inside:bool=false, target_x:float=0.0, target_y:float=50.0, target_z:float=0.0)
- `setup_physics_body`(node_path*, floor_stop_on_slope:bool, floor_max_angle:float, floor_snap_length:float, wall_min_slide_angle:float, motion_mode:int, max_slides:int, slide_on_ceiling:bool, mass:float, gravity_scale:float, linear_damp:float, angular_damp:float, freeze:bool, freeze_mode:int, continuous_cd:int, contact_monitor:bool, max_contacts_reported:int, physics_material_override)
- `get_collision_info`(node_path*, include_children:bool=true)

## profiling

- `get_performance_monitors`(category:string="")
- `get_editor_performance`()

## project

- `get_project_info`()
- `get_filesystem_tree`(path:string="res://", filter:string="", max_depth:int=10)
- `search_files`(query*, path:string="res://", file_type:string="", max_results:int=50)
- `search_in_files`(query*, path:string="res://", max_results:int=50, regex:bool=false, file_type:string="", include_addons:bool=false)
- `get_project_settings`(section:string="", key:string="")
- `set_project_setting`(key*, type:string="", value)
- `uid_to_project_path`(uid*)
- `project_path_to_uid`(path*)
- `add_autoload`(name*, path*)
- `remove_autoload`(name*)

## resource

- `read_resource`(path*, force:bool=false)
- `edit_resource`(path*, properties)
- `create_resource`(path*, type*, overwrite:bool=false, properties)
- `get_resource_preview`(path*, max_size:int=256)

## runtime

- `get_game_scene_tree`(max_depth:int=-1, script_filter:string, type_filter:string, named_only:bool=false)
- `get_game_node_properties`(node_path*, properties)
- `set_game_node_property`(node_path*, property*, value)
- `capture_frames`(count:int=5, frame_interval:int=10, half_resolution:bool=true)
- `monitor_properties`(node_path*, frame_count:int=60, frame_interval:int=1, properties)
- `execute_game_script`(code*)
- `start_recording`()
- `stop_recording`()
- `replay_recording`(events*, speed:float=1.0)
- `find_nodes_by_script`(script*, properties)
- `get_autoload`(name*, properties)
- `batch_get_properties`(nodes)
- `find_ui_elements`(type_filter:string)
- `click_button_by_text`(text*, partial:bool=true)
- `wait_for_node`(node_path*, timeout:float=5.0, poll_frames:int=5)
- `find_nearby_nodes`(radius:float, type_filter:string, group_filter:string, max_results:int, position)
- `navigate_to`(player_path:string, camera_path:string, move_speed:float, target)
- `move_to`(player_path:string, camera_path:string, arrival_radius:float, timeout:float, run:bool, look_at_target:bool, target)
- `watch_signals`(duration_ms:int=5000, node_paths, signal_filter)

## scene_3d

- `add_mesh_instance`(parent_path:string=".", name:string="MeshInstance3D", mesh_type:string="", mesh_file:string="", mesh_properties)
- `setup_lighting`(parent_path:string=".", light_type:string="", preset:string="", name:string="", energy:float=1.0, shadows:bool=false, range:float=5.0, attenuation:float=1.0, spot_angle:float=45.0, spot_angle_attenuation:float=1.0, rotation)
- `set_material_3d`(node_path*, surface_index:int=0, metallic:float=0.0, roughness:float=1.0, emission_energy:float=1.0, albedo_texture, metallic_texture, roughness_texture, normal_texture, emission, emission_color, emission_texture, transparency, cull_mode)
- `setup_environment`(parent_path:string=".", name:string="WorldEnvironment", node_path:string="", background_mode:string="sky", ambient_light_energy:float=1.0, tonemap_exposure:float=1.0, tonemap_white:float=1.0, fog_enabled:bool=false, fog_density:float=0.01, fog_light_energy:float=1.0, glow_enabled:bool=false, glow_intensity:float=0.8, glow_strength:float=1.0, glow_bloom:float=0.0, ssao_enabled:bool=false, ssao_radius:float=1.0, ssao_intensity:float=2.0, ssr_enabled:bool=false, ssr_max_steps:int=64, ssr_fade_in:float=0.15, ssr_fade_out:float=2.0, sdfgi_enabled:bool=false, sky, sun_angle_max, sky_curve, ambient_light_color, ambient_light_source, tonemap_mode, fog_light_color)
- `setup_camera_3d`(parent_path:string=".", node_path:string="", name:string="Camera3D", projection:string="", fov:float=75.0, size:float=1.0, near:float=0.05, far:float=4000.0, cull_mask:int=1048575, current:bool=false, rotation, look_at, environment_path)
- `add_gridmap`(parent_path:string=".", name:string="GridMap", node_path:string="", mesh_library_path, cell_size, cells)

## scene

- `get_scene_tree`(max_depth:int=-1)
- `get_scene_file_content`(path*)
- `create_scene`(path*, root_type:string="Node2D", root_name:string="", force:bool=false)
- `open_scene`(path*)
- `delete_scene`(path*)
- `add_scene_instance`(scene_path*, parent_path:string=".", name:string="")
- `play_scene`(mode:string="main")
- `stop_scene`()
- `save_scene`(path:string="")
- `get_scene_exports`(path*)

## script

- `list_scripts`(path:string="res://", recursive:bool=true)
- `read_script`(path*)
- `create_script`(path*, content:string="", extends:string="Node", class_name:string="", force:bool=false)
- `edit_script`(path*, force:bool=false, start_line:int, end_line:int=start_line, insert_at_line:int, replacements, content, text)
- `attach_script`(node_path*, script_path*)
- `get_open_scripts`()
- `validate_script`(path*)

## shader

- `create_shader`(path*, content:string="", shader_type:string="spatial", force:bool=false)
- `read_shader`(path*)
- `edit_shader`(path*, force:bool=false, content, replacements)
- `assign_shader_material`(node_path*, shader_path*)
- `set_shader_param`(node_path*, param*, value)
- `get_shader_params`(node_path*)

## test

- `run_test_scenario`(scene_path:string, steps)
- `assert_node_state`(node_path*, property*, operator:string="eq", expected)
- `assert_screen_text`(text*, partial:bool=true, case_sensitive:bool=true)
- `run_stress_test`(duration:float=5.0, actions)
- `get_test_report`(clear:bool=true)

## theme

- `create_theme`(path*, default_font_size:int=0)
- `set_theme_color`(node_path*, name*, color*, theme_type:string="")
- `set_theme_constant`(node_path*, name*, value:int=0)
- `set_theme_font_size`(node_path*, name*, size:int=16)
- `set_theme_stylebox`(node_path*, name*, bg_color:string="", border_color:string="", border_width:int=0, corner_radius:int=0, padding:int=0)
- `setup_control`(node_path*, anchor_preset:string="", min_size:string="", size_flags_h:string="", size_flags_v:string="", separation:int, grow_h:string="", grow_v:string="", margins)
- `get_theme_info`(node_path*)

## tilemap

- `tilemap_set_cell`(node_path*, x:int=0, y:int=0, source_id:int=0, atlas_x:int=0, atlas_y:int=0, alternative:int=0)
- `tilemap_fill_rect`(node_path*, x1:int=0, y1:int=0, x2:int=0, y2:int=0, source_id:int=0, atlas_x:int=0, atlas_y:int=0, alternative:int=0)
- `tilemap_get_cell`(node_path*, x:int=0, y:int=0)
- `tilemap_clear`(node_path*)
- `tilemap_get_info`(node_path*)
- `tilemap_get_used_cells`(node_path*, max_count:int=500)