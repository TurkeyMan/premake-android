--
-- android/vsandroid_vcxproj.lua
-- vs-android integration for vstudio.
-- Copyright (c) 2012-2015 Manu Evans and the Premake project
--

	local p = premake

	p.modules.vsandroid = { }

	local android = p.modules.android
	local vsandroid = p.modules.vsandroid
	local vc2010 = p.vstudio.vc2010
	local vstudio = p.vstudio
	local project = p.project
	local config = p.config


--
-- Add android tools to vstudio actions.
--

	if vstudio.vs2010_architectures ~= nil then
		if _ACTION >= "vs2015" then
			vstudio.vs2010_architectures.arm = "ARM"
			vstudio.vs2010_architectures.arm64 = "ARM64"
		else
			vstudio.vs2010_architectures.android = "Android"
		end
	end

--
-- Extend global properties
--
	premake.override(vc2010.elements, "globals", function (oldfn, cfg)
		local elements = oldfn(cfg)

		if cfg.system == premake.ANDROID and cfg.kind ~= premake.ANDROIDPROJ then
			-- Remove "IgnoreWarnCompileDuplicatedFilename".
			local pos = table.indexof(elements, vc2010.ignoreWarnDuplicateFilename)
			table.remove(elements, pos)
			elements = table.join(elements, {
				android.androidApplicationType
			})
		end

		return elements
	end)

	function android.androidApplicationType(cfg)
		_p(2, "<Keyword>Android</Keyword>")
		_p(2, "<RootNamespace>%s</RootNamespace>", cfg.project.name)
		_p(2, "<MinimumVisualStudioVersion>14.0</MinimumVisualStudioVersion>")
		_p(2, "<ApplicationType>Android</ApplicationType>")
		_p(2, "<ApplicationTypeRevision>%s</ApplicationTypeRevision>", cfg.androidprojectversion or iif(_ACTION == "vs2017", "3.0", "1.0"))
	end

--
-- Extend configurationProperties.
--

	premake.override(vc2010.elements, "configurationProperties", function(oldfn, cfg)
		local elements = oldfn(cfg)
		if cfg.kind ~= p.UTILITY and cfg.kind ~= p.ANDROIDPROJ and cfg.system == premake.ANDROID then
			elements = table.join(elements, {
				android.androidAPILevel,
				android.androidStlType,
			})

			if _ACTION >= "vs2015" then
				elements = table.join(elements, {
					android.thumbMode,
				})
			end
		end
		return elements
	end)

	function android.androidAPILevel(cfg)
		if cfg.androidapilevel ~= nil then
			_p(2,'<AndroidAPILevel>android-%d</AndroidAPILevel>', cfg.androidapilevel)
		end
	end

	function android.androidStlType(cfg)
		if cfg.stl ~= nil then
			if _ACTION >= "vs2015" then
				local static = {
					["none"] = nil,
					["minimal"] = "system",
					["c++"] = "gabi++_static",
					["stlport"] = "stlport_static",
					["gnu stl"] = "gnustl_static",
					["llvm libc++"] = "c++_static",
				}
				local dynamic = {
					["none"] = nil,
					["minimal"] = "system",
					["c++"] = "gabi++_shared",
					["stlport"] = "stlport_shared",
					["gnu stl"] = "gnustl_shared",
					["llvm libc++"] = "c++_shared",
				}
				local stl = iif(cfg.flags.StaticRuntime, static, dynamic);
				_p(2,'<UseOfStl>%s</UseOfStl>', stl[cfg.stl])
			else
				local static = {
					["none"]    = "none",
					["minimal"] = "system",
					["gnu stl"] = "gnustl_static",
					["stlport"] = "stlport_static",

					-- Translate others to something else
					["c++"]         = "gnustl_static",
					["llvm libc++"] = "gnustl_static",
				}
				local dynamic = {
					["none"]    = "none",
					["minimal"] = "system",
					["gnu stl"] = "gnustl_dynamic",
					["stlport"] = "stlport_dynamic",

					-- Translate others to something else
					["c++"]         = "gnustl_dynamic",
					["llvm libc++"] = "gnustl_dynamic",
				}
				local stl = iif(cfg.flags.StaticRuntime, static, dynamic);
				_p(2,'<AndroidStlType>%s</AndroidStlType>', stl[cfg.stl])
			end
		end
	end

	function android.thumbMode(cfg)
		if cfg.thumbmode then
			local thumbMode =
			{
				thumb = "Thumb",
				arm = "ARM",
				disabled = "Disabled",
			}
			_p(2,"<ThumbMode>%s</ThumbMode>", thumbMode[cfg.thumbmode])
		end
	end

	-- Note: this function is already patched in by vs2012...
	premake.override(vc2010, "platformToolset", function(oldfn, cfg)
		if cfg.system == premake.ANDROID then
			if _ACTION >= "vs2015" then
				if cfg.toolchainversion ~= nil then
					_p(2,'<PlatformToolset>%s_%s</PlatformToolset>', iif(cfg.toolset == "clang", "Clang", "GCC"), string.gsub(cfg.toolchainversion, "%.", "_"))
				end
			else
				local archMap = {
					arm = "armv5te", -- should arm5 be default? vs-android thinks so...
					arm5 = "armv5te",
					arm7 = "armv7-a",
					mips = "mips",
					x86 = "x86",
				}
				local arch = cfg.architecture or "arm"

				if (cfg.architecture ~= nil or cfg.toolchainversion ~= nil) and archMap[arch] ~= nil then
					local defaultToolsetMap = {
						arm = "arm-linux-androideabi-",
						armv5 = "arm-linux-androideabi-",
						armv7 = "arm-linux-androideabi-",
						aarch64 = "aarch64-linux-android-",
						mips = "mipsel-linux-android-",
						mips64 = "mips64el-linux-android-",
						x86 = "x86-",
						x86_64 = "x86_64-",
					}
					local toolset = defaultToolsetMap[arch]

					if cfg.toolset == "clang" then
						error("The clang toolset is not yet supported by vs-android", 2)
						toolset = toolset .. "clang"
					elseif cfg.toolset and cfg.toolset ~= "gcc" then
						error("Toolset not supported by the android NDK: " .. cfg.toolset, 2)
					end

					local version = cfg.toolchainversion or iif(cfg.toolset == "clang", "3.5", "4.9")

					_p(2,'<PlatformToolset>%s</PlatformToolset>', toolset .. version)
					_p(2,'<AndroidArch>%s</AndroidArch>', archMap[arch])
				end
			end
		else
			oldfn(cfg)
		end
	end)


--
-- Extend clCompile.
--

	premake.override(vc2010.elements, "clCompile", function(oldfn, cfg)
		local elements = oldfn(cfg)
		if cfg.system == premake.ANDROID then
			elements = table.join(elements, {
				android.debugInformation,
				android.strictAliasing,
				android.thumbMode,
				android.fpu,
				android.pic,
--				android.ShortEnums,
			})
			if _ACTION >= "vs2015" then
				table.remove(elements, table.indexof(elements, vc2010.debugInformationFormat))
				table.remove(elements, table.indexof(elements, android.thumbMode))
				elements = table.join(elements, {
					android.cStandard,
					android.cppStandard,
				})
			end
		end
		return elements
	end)

	function android.debugInformation(cfg)
		if cfg.flags.Symbols then
			_p(3,'<GenerateDebugInformation>true</GenerateDebugInformation>')
		end
	end

	function android.strictAliasing(cfg)
		if cfg.strictaliasing ~= nil then
			_p(3,'<StrictAliasing>%s</StrictAliasing>', iif(cfg.strictaliasing == "Off", "false", "true"))
		end
	end

	function android.thumbMode(cfg)
		if cfg.flags.Thumb then
			_p(3,'<ThumbMode>true</ThumbMode>')
		end
	end

	function android.fpu(cfg)
		if cfg.fpu ~= nil then
			_p(3,'<SoftFloat>true</SoftFloat>', iif(cfg.fpu == "Software", "true", "false"))
		end
	end

	function android.pic(cfg)
		-- TODO: We only have a flag to turn it on, but android is on by default
		--       it seems we would rather have a flag to turn it off...
--		if cfg.pic ~= nil then
--			_p(3,'<PositionIndependentCode>%s</PositionIndependentCode>', iif(cfg.pic == "On", "true", "false"))
--		end
	end

	function android.cStandard(cfg)
		if cfg.cppdialect == "C89" then
			_p(3, '<CLanguageStandard>c89</CLanguageStandard>')
		elseif cfg.cppdialect == "C99" then
			_p(3, '<CLanguageStandard>c99</CLanguageStandard>')
		elseif cfg.cppdialect == "C11" then
			_p(3, '<CLanguageStandard>c11</CLanguageStandard>')
		elseif cfg.cppdialect == "gnu99" then
			_p(3, '<CLanguageStandard>gnu99</CLanguageStandard>')
		elseif cfg.cppdialect == "gnu11" then
			_p(3, '<CLanguageStandard>gnu11</CLanguageStandard>')
		end
	end

	function android.cppStandard(cfg)
		if cfg.cppdialect == "C++98" then
			_p(3, '<CppLanguageStandard>c++98</CppLanguageStandard>')
		elseif cfg.cppdialect == "C++11" then
			_p(3, '<CppLanguageStandard>c++11</CppLanguageStandard>')
		elseif cfg.cppdialect == "C++14" then
			_p(3, '<CppLanguageStandard>c++1y</CppLanguageStandard>')
		elseif cfg.cppdialect == "gnu++98" then
			_p(3, '<CppLanguageStandard>gnu++98</CppLanguageStandard>')
		elseif cfg.cppdialect == "gnu++11" then
			_p(3, '<CppLanguageStandard>gnu++11</CppLanguageStandard>')
		elseif cfg.cppdialect == "gnu++14" then
			_p(3, '<CppLanguageStandard>gnu++1y</CppLanguageStandard>')
		end
	end

	p.override(p.vstudio.vc2010, "warningLevel", function(oldfn, cfg)
		if _ACTION >= "vs2015" and cfg.system == p.ANDROID and cfg.warnings and cfg.warnings ~= "Off" then
			p.vstudio.vc2010.element("WarningLevel", nil, "EnableAllWarnings")
		elseif (_ACTION >= "vs2015" and cfg.system == p.ANDROID and cfg.warnings) or not (_ACTION >= "vs2015" and cfg.system == p.ANDROID) then
			oldfn(cfg)
		end
	end)

	premake.override(vc2010, "exceptionHandling", function(oldfn, cfg)
		if cfg.system == premake.ANDROID then
			-- Note: Android defaults to 'off'
			if not cfg.flags.NoExceptions then
				_p(3,'<GccExceptionHandling>true</GccExceptionHandling>')
			end
		else
			oldfn(cfg)
		end
	end)

	premake.override(vc2010, "runtimeTypeInfo", function(oldfn, cfg)
		if cfg.system == premake.ANDROID then
			-- Note: Android defaults to 'off'
			if not cfg.flags.NoRTTI then
				_p(3,'<RuntimeTypeInfo>true</RuntimeTypeInfo>')
			end
		else
			oldfn(cfg)
		end
	end)


--
-- Extend Link.
--

	premake.override(vc2010, "generateDebugInformation", function(oldfn, cfg)
		-- Note: Android specifies the debug info in the clCompile section
		if cfg.system ~= premake.ANDROID then
			oldfn(cfg)
		end
	end)


--
-- Add android tools to vstudio actions.
--

	premake.override(vc2010.elements, "itemDefinitionGroup", function(oldfn, cfg)
		local elements = oldfn(cfg)
		if cfg.system == premake.ANDROID and _ACTION < "vs2015" then
			elements = table.join(elements, {
				android.antBuild,
			})
		end
		return elements
	end)

	function android.antPackage(cfg)
		_p(2,'<AntPackage>')
		_p(3,'<AndroidAppLibName>$(RootNamespace)</AndroidAppLibName>')
		_p(2,'</AntPackage>')
	end

	function android.antBuild(cfg)
		if cfg.kind == premake.STATICLIB or cfg.kind == premake.SHAREDLIB then
			return
		end

		_p(2,'<AntBuild>')
		_p(3,'<AntBuildType>%s</AntBuildType>', iif(premake.config.isDebugBuild(cfg), "Debug", "Release"))
		_p(2,'</AntBuild>')
	end

	premake.override(vc2010, "additionalCompileOptions", function(oldfn, cfg, condition)
		if cfg.system == premake.ANDROID then
			vsandroid.additionalOptions(cfg, condition)
		end
		return oldfn(cfg, condition)
	end)

	premake.override(vc2010.elements, "user", function(oldfn, cfg)
		if cfg.system == p.ANDROID then
			return {}
		else
			return oldfn(cfg)
		end
	end)

--
-- Add options unsupported by vs-android UI to <AdvancedOptions>.
--
	function vsandroid.additionalOptions(cfg)
		if _ACTION >= "vs2015" then

		else
			local function alreadyHas(t, key)
				for _, k in ipairs(t) do
					if string.find(k, key) then
						return true
					end
				end
				return false
			end

			if not cfg.architecture or string.startswith(cfg.architecture, "arm") then
				-- we might want to define the arch to generate better code
--				if not alreadyHas(cfg.buildoptions, "-march=") then
--					if cfg.architecture == "armv6" then
--						table.insert(cfg.buildoptions, "-march=armv6")
--					elseif cfg.architecture == "armv7" then
--						table.insert(cfg.buildoptions, "-march=armv7")
--					end
--				end

				-- ARM has a comprehensive set of floating point options
				if cfg.fpu ~= "Software" and cfg.floatabi ~= "soft" then

					if cfg.architecture == "armv7" then

						-- armv7 always has VFP, may not have NEON

						if not alreadyHas(cfg.buildoptions, "-mfpu=") then
							if cfg.vectorextensions == "NEON" then
								table.insert(cfg.buildoptions, "-mfpu=neon")
							elseif cfg.fpu == "Hardware" or cfg.floatabi == "softfp" or cfg.floatabi == "hard" then
								table.insert(cfg.buildoptions, "-mfpu=vfpv3-d16") -- d16 is the lowest common denominator
							end
						end

						if not alreadyHas(cfg.buildoptions, "-mfloat-abi=") then
							if cfg.floatabi == "hard" then
								table.insert(cfg.buildoptions, "-mfloat-abi=hard")
							else
								-- Android should probably use softfp by default for compatibility
								table.insert(cfg.buildoptions, "-mfloat-abi=softfp")
							end
						end

					else

						-- armv5/6 may not have VFP

						if not alreadyHas(cfg.buildoptions, "-mfpu=") then
							if cfg.fpu == "Hardware" or cfg.floatabi == "softfp" or cfg.floatabi == "hard" then
								table.insert(cfg.buildoptions, "-mfpu=vfp")
							end
						end

						if not alreadyHas(cfg.buildoptions, "-mfloat-abi=") then
							if cfg.floatabi == "softfp" then
								table.insert(cfg.buildoptions, "-mfloat-abi=softfp")
							elseif cfg.floatabi == "hard" then
								table.insert(cfg.buildoptions, "-mfloat-abi=hard")
							end
						end

					end

				elseif cfg.floatabi == "soft" then

					table.insert(cfg.buildoptions, "-mfloat-abi=soft")

				end

				if cfg.endian == "Little" then
					table.insert(cfg.buildoptions, "-mlittle-endian")
				elseif cfg.endian == "Big" then
					table.insert(cfg.buildoptions, "-mbig-endian")
				end

			elseif cfg.architecture == "mips" then

				-- TODO...

				if cfg.vectorextensions == "MXU" then
					table.insert(cfg.buildoptions, "-mmxu")
				end

			elseif cfg.architecture == "x86" then

				-- TODO...

			end
		end
	end
