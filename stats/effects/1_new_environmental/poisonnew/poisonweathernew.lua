require("/scripts/vec2.lua")

function init()
  self.timerRadioMessage = 0  -- initial delay for secondary radiomessages
    
  -- Environment Configuration --
  self.biomeTemp = config.getParameter("biomeTemp",0)              -- sets the base variable for the biome/effect
  self.windLevel =  world.windLevel(mcontroller.position())        -- is there wind? we note that too
  self.baseDmg = config.getParameter("baseDmgPerTick",0)           -- damage per tick
  self.baseDebuff = config.getParameter("baseDebuffPerTick",0)     --debuff per tick
  self.biomeThreshold = config.getParameter("biomeThreshold",0)    -- base Modifier (tier)
  self.biomeNight = config.getParameter("biomeNight",0)            -- is this effect worse at night? how much?
  self.situationPenalty = config.getParameter("situationPenalty",0)-- situational modifiers are seldom applied...but provided if needed
  self.liquidPenalty = config.getParameter("liquidPenalty",0)      -- does liquid make things worse? how much?  
  
  self.baseRate = config.getParameter("baseRate",0)                -- base Timer rate
  self.biomeTimer = config.getParameter("baseRate",0)              -- same as above. pare out.
  self.biomeTimer2=  (self.baseRate * (1 + status.stat("poisonResistance",0)) *20)   --this second timer is for secondary effects (debuffs) and are much slower

  -- activate visuals and check stats
  world.sendEntityMessage(entity.id(), "queueRadioMessage", "ffbiomepoison", 1.0) -- send player a warning
  activateVisualEffects() 
  script.setUpdateDelta(5)
end

-- alert the player that they are affected
function activateVisualEffects()
  effect.setParentDirectives("fade=558833=0.7")
  animator.setParticleEmitterOffsetRegion("poisonbreath", mcontroller.boundBox())
  animator.setParticleEmitterActive("poisonbreath", true) 
end


function setEffectDamage()
  return ( ( self.baseDmg + self.situationPenalty + self.liquidPenalty + self.biomeNight ) *  (1 -status.stat("poisonResistance",0) ) * self.biomeThreshold  )
end

function setEffectDebuff()
  return ( ( ( self.baseDebuff + self.liquidPenalty + self.biomeNight ) * self.biomeTemp ) * (1 -status.stat("poisonResistance",0) * self.biomeThreshold) )
end

function setEffectTime()
  return (( self.biomeThreshold * self.baseRate ) * (1 +status.stat("poisonResistance",0)))
end

function update(dt)
  self.damageApply = setEffectDamage()
  self.debuffApply = setEffectDebuff()
  self.baseRate = setEffectTime()

      if status.stat("poisonResistance",0) < 1.0 then  
        activateVisualEffects() 
        self.timerRadioMessage = self.timerRadioMessage - dt
        self.biomeTimer = self.biomeTimer - dt  
        self.biomeTimer2 = self.biomeTimer2 - dt

        -- first we check how windy it is
        self.windLevel =  world.windLevel(mcontroller.position())

        -- is it nighttime or above ground? 
        if self.windLevel >= 40 then
                if self.timerRadioMessage == 0 then
                  world.sendEntityMessage(entity.id(), "queueRadioMessage", "ffbiomepoisonwind", 1.0) -- send player a warning
                  self.timerRadioMessage = 60
                    self.biomeTemp = self.biomeTemp * 1.6
  		      self.damageApply = setEffectDamage()
  		      self.debuffApply = setEffectDebuff()
  		      self.baseRate = setEffectTime()                  
		end
        end
               
        if self.biomeTimer <= 0 then
          if self.biomeTimer2 <= 0 then
            effect.addStatModifierGroup({
              {stat = "protection", amount = -self.baseDebuff  },
              {stat = "powerMultiplier", amount = -(self.baseDebuff/100 )  }
            })
            
            self.biomeTimer2 = (self.biomeTimer * (1 + status.stat("poisonResistance",0))) * 2
          end 
          self.biomeTimer = self.baseRate
          makeAlert()
        end

        self.damageApply = (self.damageApply /50)  
        status.modifyResource("health", -self.damageApply * dt)

        -- less agile the more damaged you are
        mcontroller.controlModifiers({  
	 airJumpModifier = 1 * (status.resource("health")/100), 
	 speedModifier = 1 * (status.resource("health")/100)
        }) 
      end     
end       

function makeAlert()
   animator.playSound("bolt")
end

function uninit()

end