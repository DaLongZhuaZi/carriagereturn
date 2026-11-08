import { MachineBlueprint } from '../BlueprintTypes';

/** 1930s 蓝图：值与 §4 锚点表一致。 */
export const BLUEPRINT_1930: MachineBlueprint = {
  leverSizeRatio: 0.3264,
  leverAspect: 0.3264,
  bracketAspect: 1.2921,
  bracketPivotX: 0.519,
  bracketPivotY: 0.199,
  leverPivotY: 0.960,
  bracketRawfile: (): Resource => $rawfile('layers/1930s-portable/lever-pivot-bracket.png'),
};