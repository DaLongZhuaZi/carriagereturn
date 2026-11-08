import { MachineBlueprint } from '../BlueprintTypes';

/** 1920s 蓝图（冻结）：常量与 7fd6305^ 原件逐值一致，不许改。 */
export const BLUEPRINT_1920: MachineBlueprint = {
  leverSizeRatio: 0.212,
  leverAspect: 536 / 2522,
  bracketAspect: 0.8042,
  bracketPivotX: 0.503,
  bracketPivotY: 0.293,
  rollerWidthRatio: 0.9528,
  leverPivotY: 0.952,
  bracketRawfile: (): Resource => $rawfile('layers/1920s-upright/lever-pivot-bracket.png'),
};